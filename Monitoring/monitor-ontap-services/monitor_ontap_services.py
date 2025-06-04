#!/bin/python3
################################################################################
# THIS SOFTWARE IS PROVIDED BY NETAPP "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL NETAPP BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR'
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
################################################################################
#
################################################################################
# This program is used to monitor some of Data ONTAP services (EMS Message,
# Snapmirror relationships, quotas) running under AMS, and alert on any
# "matching conditions."  It is intended to be run as a Lambda function, but
# can be run as a standalone program.
#
# Version: %%VERSION%%
# Date: %%DATE%%
################################################################################

import json
import re
import os
import datetime
import pytz
import logging
from logging.handlers import SysLogHandler
from cronsim import CronSim
import urllib3
from urllib3.util import Retry
import botocore
import boto3

eventResilience = 4 # Times an event has to be missing before it is removed
                    # from the alert history.
                    # This was added since the Ontap API that returns EMS
                    # events would often drop some events and then including
                    # them in the subsequent calls. If I don't "age" the
                    # alert history duplicate alerts will be sent.
initialVersion = "Initial Run"  # The version to store if this is the first
                                # time the program has been run against a
                                # FSxN.

################################################################################
# This function is used to extract the one-, two-, or three-digit number from
# the string passed in, starting at the 'start' character. Then, multiple it
# by the unit after the number:
# D = Day = 60*60*24
# H = Hour = 60*60
# M = Minutes = 60
#
# It returns a tuple that has the extracted number and the end position.
################################################################################
def getNumber(string, start):

    if len(string) <= start:
        return (0, start)
    #
    # Check to see if it is a 1, 2 or 3 digit number.
    startp1=start+1   # Single digit
    startp2=start+2   # Double digit
    startp3=start+3   # Triple digit
    if re.search('[0-9]', string[startp1:startp2]) and re.search('[0-9]', string[startp2:startp3]):
        end=startp3
    elif re.search('[0-9]', string[startp1:startp2]):
        end=startp2
    else:
        end=startp1

    num=int(string[start:end])

    endp1=end+1
    if string[end:endp1] == "D":
        num=num*60*60*24
    elif string[end:endp1] == "H":
        num=num*60*60
    elif string[end:endp1] == "M":
        num=num*60
    elif string[end:endp1] != "S":
        logger.warning(f'Unknown lag time specifier "{string[end:endp1]}".')

    return (num, endp1)

################################################################################
# This function is used to parse the lag time string returned by the
# ONTAP API and return the equivalent seconds it represents.
# The input string is assumed to follow this pattern "P#DT#H#M#S" where
# each of those "#" can be one to three digits long. Also, if the lag isn't
# more than 24 hours, then the "#D" isn't there and the string simply starts
# with "PT". Similarly, if the lag time isn't more than an hour then the "#H"
# string is missing.
################################################################################
def parseLagTime(string):
    #
    num=0
    #
    # First check to see if the Day field is there, by checking to see if the
    # second character is a digit. If not, it is assumed to be 'T'.
    includesDay=False
    if re.search('[0-9]', string[1:2]):
        includesDay=True
        start=1
    else:
        start=2
    data=getNumber(string, start)
    num += data[0]

    start=data[1]
    #
    # If there is a 'D', then there is a 'T' between the D and the # of hours
    # so skip pass it.
    if includesDay:
        start += 1
    data=getNumber(string, start)
    num += data[0]

    start=data[1]
    data=getNumber(string, start)
    num += data[0]

    start=data[1]
    data=getNumber(string, start)
    num += data[0]

    return(num)

################################################################################
# This function checks to see if an event is in the events array based on
# the unique Identifier passed in. It will also update the "refresh" field on
# any matches.
################################################################################
def eventExist (events, uniqueIdentifier):
    for event in events:
        if event["index"] == uniqueIdentifier:
            event["refresh"] = eventResilience
            return True

    return False

################################################################################
# This function makes an API call to the FSxN to ensure it is up. If the
# errors out, then it sends an alert, and returns 'False'. Otherwise it returns
# 'True'.
################################################################################
def checkSystem():
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger, clusterTimezone

    changedEvents = False
    #
    # Get the previous status.
    try:
        data = s3Client.get_object(Key=config["systemStatusFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then this must be the
        # first time this script has run against thie filesystem so create an
        # initial status structure.
        if err.response['Error']['Code'] == "NoSuchKey":
            fsxStatus = {
                "systemHealth": True,
                "version" : initialVersion,
                "numberNodes" : 2,
                "downInterfaces" : []
            }
            changedEvents = True
        else:
            raise err
    else:
        fsxStatus = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Get the cluster name, ONTAP version and timezone from the FSxN.
    # This is also a way to test that the FSxN cluster is accessible.
    badHTTPStatus = False
    try:
        endpoint = f'https://{config["OntapAdminServer"]}/api/cluster?fields=version,name,timezone'
        response = http.request('GET', endpoint, headers=headers, timeout=5.0)
        if response.status == 200:
            if not fsxStatus["systemHealth"]:
                fsxStatus["systemHealth"] = True
                changedEvents = True

            data = json.loads(response.data)
            if config["awsAccountId"] != None:
                clusterName = f'{data["name"]}({config["awsAccountId"]})'
            else:
                clusterName = data['name']
            #
            # The following assumes that the format of the "full" version
            # looks like: "NetApp Release 9.13.1P6: Tue Dec 05 16:06:25 UTC 2023".
            # The reason for looking at the "full" instead of the individual
            # keys (generation, major, minor) is because they don't provide
            # the patch level. :-(
            clusterVersion = data["version"]["full"].split()[2].replace(":", "")
            if fsxStatus["version"] == initialVersion:
                fsxStatus["version"] = clusterVersion
            #
            # Get the Timezone for SnapMirror lag time calculations.
            clusterTimezone = data["timezone"]["name"]
        else:
            badHTTPStatus = True
            raise Exception(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
    except:
        if fsxStatus["systemHealth"]:
            if config["awsAccountId"] != None:
                clusterName = f'{config["OntapAdminServer"]}({config["awsAccountId"]})'
            else:
                clusterName = config["OntapAdminServer"]
            if badHTTPStatus:
                message = f'CRITICAL: Received a non 200 HTTP status code ({response.status}) when trying to access {clusterName}.'
            else:
                message = f'CRITICAL: Failed to issue API against {clusterName}. Cluster could be down.'
            sendAlert(message, "CRITICAL")
            fsxStatus["systemHealth"] = False
            changedEvents = True

    if changedEvents:
        s3Client.put_object(Key=config["systemStatusFilename"], Bucket=config["s3BucketName"], Body=json.dumps(fsxStatus).encode('UTF-8'))
    #
    # If the cluster is done, return false so the program can exit cleanly.
    return(fsxStatus["systemHealth"])

################################################################################
# This function checks the following things:
#   o If the ONTAP version has changed.
#   o If one of the nodes are down.
#   o If a network interface is down.
#
# ASSUMPTIONS: That checkSystem() has been called before it.
################################################################################
def checkSystemHealth(service):
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger

    changedEvents = False
    #
    # Get the previous status.
    # Shouldn't have to check for status of the get_object() call, to see if the object exist or not,
    # since "checkSystem()" should already have been called and it creates the object if it doesn't
    # already exist. So, if there is a failure, it should be something else than "non-existent".
    data = s3Client.get_object(Key=config["systemStatusFilename"], Bucket=config["s3BucketName"])
    fsxStatus = json.loads(data["Body"].read().decode('UTF-8'))

    for rule in service["rules"]:
        for key in rule.keys():
            lkey = key.lower()
            if lkey == "versionchange":
                if rule[key] and clusterVersion != fsxStatus["version"]:
                    message = f'NOTICE: The ONTAP vesion changed on cluster {clusterName} from {fsxStatus["version"]} to {clusterVersion}.'
                    sendAlert(message, "INFO")
                    fsxStatus["version"] = clusterVersion
                    changedEvents = True
            elif lkey == "failover":
                #
                # Check that both nodes are available.
                # Using the CLI passthrough API because I couldn't find the equivalent API call.
                if rule[key]:
                    endpoint = f'https://{config["OntapAdminServer"]}/api/private/cli/system/node/virtual-machine/instance/show-settings'
                    response = http.request('GET', endpoint, headers=headers)
                    if response.status == 200:
                        data = json.loads(response.data)
                        if data["num_records"] != fsxStatus["numberNodes"]:
                            message = f'Alert: The number of nodes on cluster {clusterName} went from {fsxStatus["numberNodes"]} to {data["num_records"]}.'
                            sendAlert(message, "INFO")
                            fsxStatus["numberNodes"] = data["num_records"]
                            changedEvents = True
                    else:
                        logger.warning(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
            elif lkey == "networkinterfaces":
                if rule[key]:
                    endpoint = f'https://{config["OntapAdminServer"]}/api/network/ip/interfaces?fields=state'
                    response = http.request('GET', endpoint, headers=headers)
                    if response.status == 200:
                        #
                        # Decrement the refresh field to know if any events have really gone away.
                        for interface in fsxStatus["downInterfaces"]:
                            interface["refresh"] -= 1

                        data = json.loads(response.data)
                        for interface in data["records"]:
                            if interface.get("state") != None and interface["state"] != "up":
                                uniqueIdentifier = interface["name"]
                                if(not eventExist(fsxStatus["downInterfaces"], uniqueIdentifier)): # Resets the refresh key.
                                    message = f'Alert: Network interface {interface["name"]} on cluster {clusterName} is down.'
                                    sendAlert(message, "WARNING")
                                    event = {
                                        "index": uniqueIdentifier,
                                        "refresh": eventResilience
                                    }
                                    fsxStatus["downInterfaces"].append(event)
                                    changedEvents = True
                        #
                        # After processing the records, see if any events need to be removed.
                        i = 0
                        while i < len(fsxStatus["downInterfaces"]):
                            if fsxStatus["downInterfaces"][i]["refresh"] <= 0:
                                logger.debug(f'Deleting interface: {fsxStatus["downInterfaces"][i]["index"]}')
                                del fsxStatus["downInterfaces"][i]
                                changedEvents = True
                            else:
                                if fsxStatus["downInterfaces"][i]["refresh"] != eventResilience:
                                    changedEvents = True
                                i += 1
                    else:
                        logger.warning(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
            else:
                logger.warning(f'Unknown System Health alert type: "{key}".')

    if changedEvents:
        s3Client.put_object(Key=config["systemStatusFilename"], Bucket=config["s3BucketName"], Body=json.dumps(fsxStatus).encode('UTF-8'))

################################################################################
# This function processes the EMS events.
################################################################################
def processEMSEvents(service):
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger

    changedEvents = False
    #
    # Get the saved events so we can ensure we are only reporting on new ones.
    try:
        data = s3Client.get_object(Key=config["emsEventsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert it sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            events = []
        else:
            raise err
    else:
        events = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Decrement the refresh field to know if any records have really gone away.
    for event in events:
        event["refresh"] -= 1
    #
    # Run the API call to get the current list of EMS events.
    endpoint = f'https://{config["OntapAdminServer"]}/api/support/ems/events?return_timeout=15'
    response = http.request('GET', endpoint, headers=headers)
    if response.status == 200:
        data = json.loads(response.data)
        #
        # Process the events to see if there are any new ones.
        print(f'Received {len(data["records"])} EMS records.')
        logger.debug(f'Received {len(data["records"])} EMS records.')
        for record in data["records"]:
            for rule in service["rules"]:
                messageFilter = rule.get("filter")
                if messageFilter == None or messageFilter == "":
                    messageFilter = "ThisShouldn'tMatchAnything"

                if (not re.search(messageFilter, record["log_message"]) and
                    re.search(rule["name"], record["message"]["name"]) and
                    re.search(rule["severity"], record["message"]["severity"]) and
                    re.search(rule["message"], record["log_message"])):
                    if (not eventExist (events, record["index"])):  # This resets the "refresh" field if found.
                        message = f'{record["time"]} : {clusterName} {record["message"]["name"]}({record["message"]["severity"]}) - {record["log_message"]}'
                        useverity=record["message"]["severity"].upper()
                        if useverity == "EMERGENCY":
                            sendAlert(message, "CRITICAL")
                        elif useverity == "ALERT":
                            sendAlert(message, "ERROR")
                        elif useverity == "ERROR":
                            sendAlert(message, "WARNING")
                        elif useverity == "NOTICE" or useverity == "INFORMATIONAL":
                            sendAlert(message, "INFO")
                        elif useverity == "DEBUG":
                            sendAlert(message, "DEBUG")
                        else:
                            sendAlert(f'Received unknown severity from ONTAP "{record["message"]["severity"]}". The message received is next.', "INFO")
                            sendAlert(message, "INFO")

                        changedEvents = True
                        event = {
                                "index": record["index"],
                                "time": record["time"],
                                "messageName": record["message"]["name"],
                                "message": record["log_message"],
                                "refresh": eventResilience
                                }
                        events.append(event)
        #
        # Now that we have processed all the events, check to see if any events should be deleted.
        i = 0
        while i < len(events):
            if events[i]["refresh"] <= 0:
                logger.debug(f'Deleting event: {events[i]["time"]} : {events[i]["message"]}')
                del events[i]
                changedEvents = True
            else:
                # If an event wasn't refreshed, then we need to save the new refresh count.
                if events[i]["refresh"] != eventResilience:
                    changedEvents = True
                i += 1
        #
        # If the events array changed, save it.
        if changedEvents:
            s3Client.put_object(Key=config["emsEventsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(events).encode('UTF-8'))
    else:
        logger.warning(f'API call to {endpoint} failed. HTTP status code: {response.status}.')

################################################################################
# This function is used to find an existing SM relationship based on the source
# and destinatino path passed in. It returns None if one isn't found
################################################################################
def getPreviousSMRecord(relationShips, uuid):
    for relationship in relationShips:
        if relationship.get('uuid') == uuid:
            relationship['refresh'] = True
            return(relationship)

    return(None)

################################################################################
# This function will convert seconds into an ascii string of number days, hours,
# minutes, and seconds. It will return the string.
################################################################################
def lagTimeStr(seconds):
    days = seconds // (60 * 60 * 24)
    seconds = seconds - (days * (60 * 60 * 24))
    hours = seconds // (60 * 60)
    seconds = seconds - (hours * (60 * 60))
    minutes = seconds // 60
    seconds = seconds - (minutes * 60)

    timeStr=""
    if days > 0:
        plural = "s" if days != 1 else ""
        timeStr = f'{days} day{plural} '
    if hours > 0 or days > 0:
        plural = "s" if hours != 1 else ""
        timeStr += f'{hours} hour{plural} '
    if minutes > 0 or days > 0 or hours > 0:
        plural = "s" if minutes != 1 else ""
        timeStr += f'{minutes} minute{plural} and '
    plural = "s" if seconds != 1 else ""
    timeStr += f'{seconds} second{plural}'
    return timeStr

################################################################################
# This function converts an array of numbers to a comma separated string. If
# the array is empty, it returns "*".
################################################################################
def convertArrayToString(array):

    text = ""
    for item in array:
        if text != "":
             text += ","
        text += str(item)

    return text if text != "" else "*"

################################################################################
# This function takes a schedule dictionary and returns the last time it should
# run. It returns the time in seconds since the UNIX epoch.
################################################################################
def getLastRunTime(scheduleUUID):
    global config, http, headers, clusterName, clusterVersion, logger, clusterTimezone

    minutes = ""
    hours = ""
    months = ""
    daysOfMonth = ""
    daysOfWeek = ""
    #
    # Run the API call to get the schedule information.
    endpoint = f'https://{config["OntapAdminServer"]}/api/cluster/schedules/{scheduleUUID}?fields=*&return_timeout=15'
    response = http.request('GET', endpoint, headers=headers)
    if response.status == 200:
        schedule = json.loads(response.data)

        if schedule['cron'].get("minutes") is not None:
            minutes = convertArrayToString(schedule['cron']['minutes'])
        else:
            minutes = "*"

        if schedule['cron'].get("hours") is not None:
            hours = convertArrayToString(schedule['cron']['hours'])
        else:
            hours = "*"

        if schedule['cron'].get("days") is not None:
            daysOfMonth = convertArrayToString(schedule['cron']['days'])
        else:
            daysOfMonth = "*"

        if schedule['cron'].get("months") is not None:
            months = convertArrayToString(schedule['cron']['months'])
        else:
            months = "*"

        if schedule['cron'].get("weekdays") is not None:
            daysOfWeek = convertArrayToString(schedule['cron']['weekdays'])
        else:
            daysOfWeek = "*"
        #
        # Create the cron expression.
        cron_expression = f"{minutes} {hours} {daysOfMonth} {months} {daysOfWeek}"
        #
        # Initialize CronSim with the cron expression and current time.
        curTime = datetime.datetime.now(pytz.timezone(clusterTimezone) if clusterTimezone != None else datetime.timezone.utc)
        curTimeSec = curTime.timestamp()
        it = CronSim(cron_expression, curTime, reverse=True)
        #
        # Get the last run time.
        lastRunTime = next(it)
        lastRunTimeSec = lastRunTime.timestamp()
        return int(lastRunTimeSec)
    else:
        logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
        return -1

################################################################################
################################################################################
def getPolicySchedule(policyUUID):
    global config, http, headers, clusterName, clusterVersion, logger

    # Run the API call to get the policy information.
    endpoint = f'https://{config["OntapAdminServer"]}/api/snapmirror/policies/{policyUUID}?fields=*&return_timeout=15'
    response = http.request('GET', endpoint, headers=headers)
    if response.status == 200:
        data = json.loads(response.data)
        if data.get('transfer_schedule') != None:
            return data['transfer_schedule']['uuid']
        else:
            return None
    else:
        logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
        return None

################################################################################
# This function is used to find the last time a SnapMirror relationship should
# have been updated. It returns the time in seconds since the UNIX epoch.
################################################################################
def getLastScheduledUpdate(record):
    global config, http, headers, clusterName, clusterVersion, logger
    #
    # First check to see if there is a schedule associated with the SM relationship.
    if record.get("transfer_schedule") is not None:
        lastRunTime = getLastRunTime(record["transfer_schedule"]["uuid"])
    else:
        #
        # If there is no schedule at the relationship level, check to see
        # if the policy has one.
        scheduleUUID = getPolicySchedule(record["policy"]["uuid"])
        if scheduleUUID is not None:
            lastRunTime = getLastRunTime(scheduleUUID)
        else:
            lastRunTime = -1
    return lastRunTime

################################################################################
# This function is used to check SnapMirror relationships.
################################################################################
def processSnapMirrorRelationships(service):
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger, clusterTimezone
    #
    # Get the saved events so we can ensure we are only reporting on new ones.
    try:
        data = s3Client.get_object(Key=config["smEventsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert is sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            events = []
        else:
            raise err
    else:
        events = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Decrement the refresh field to know if any records have really gone away.
    for event in events:
        event["refresh"] -= 1

    changedEvents=False
    #
    # Get the saved SM relationships.
    try:
        data = s3Client.get_object(Key=config["smRelationshipsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert is sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            smRelationships = []
        else:
            raise err
    else:
        smRelationships = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Set the refresh to False to know if any of the relationships still exist.
    for relationship in smRelationships:
        relationship["refresh"] = False

    updateRelationships = False
    #
    # Get the current time in seconds since UNIX epoch 01/01/1970.
    curTimeSeconds = int(datetime.datetime.now(pytz.timezone(clusterTimezone) if clusterTimezone != None else datetime.timezone.utc).timestamp())
    #
    # Consolidate all the rules so we can decide how to process lagtime.
    maxLagTime = None
    maxLagTimePercent = None
    healthy = None
    stalledTransferSeconds = None
    offline = None
    for rule in service["rules"]:
        for key in rule.keys():
            lkey = key.lower()
            if lkey == "maxlagtime":
                maxLagTime = rule[key]
                maxLagTimeKey = key
            elif lkey == "maxlagtimepercent":
                maxLagTimePercent = rule[key]
                maxLagTimePercentKey = key
            elif lkey == "healthy":
                healthy = rule[key]
                healthyKey = key
            elif lkey == "stalledtransferseconds":
                stalledTransferSeconds = rule[key]
                stalledTransferSecondsKey = key
            else:
                logger.warning(f'Unknown snapmirror alert type: "{key}".')
    #
    # Run the API call to get the current state of all the snapmirror relationships.
    endpoint = f'https://{config["OntapAdminServer"]}/api/snapmirror/relationships?fields=*&return_timeout=15'
    response = http.request('GET', endpoint, headers=headers)
    if response.status == 200:
        data = json.loads(response.data)
        for record in data["records"]:
            #
            # Since there are multiple ways to process lag time, make sure to only do it one way for each relationship.
            processedLagTime = False
            #
            # If the source cluster isn't defined, then assume it is a local SM relationship.
            if record['source'].get('cluster') is None:
                sourceClusterName = clusterName
            else:
                sourceClusterName = record['source']['cluster']['name']
            #
            # For lag time if maxLagTimePercent is defined check to see if there is a schedule,
            # if there is a schedule alert on that otherrwise alert on the maxLagTime.
            # But, first check that lag_time is defined, and that the state is not "uninitialized",
            # since the lag_time is set to the oldest snapshot of the source volume which would
            # cause a false positive.
            if record.get("lag_time") is not None and record["state"].lower() != "uninitialized":
                lagSeconds = parseLagTime(record["lag_time"])
                if maxLagTimePercent is not None:
                    lastScheduledUpdate = getLastScheduledUpdate(record)
                    if lastScheduledUpdate != -1:
                        processedLagTime = True
                        if lagSeconds > ((curTimeSeconds - lastScheduledUpdate) * maxLagTimePercent/100):
                            #
                            # If the transfer is in progress, and they have stalled transfer alert enabled, we don't need to alert on the lag time.
                            if not (record.get("transfer") is not None and record["transfer"]["state"].lower() in ["transferring", "finalizing", "preparing", "fasttransferring"] and stalledTransferSeconds is not None):
                                uniqueIdentifier = record["uuid"] + "_" + maxLagTimePercentKey
                                if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                    timeStr = lagTimeStr(lagSeconds)
                                    asciiTime = datetime.datetime.fromtimestamp(lastScheduledUpdate).strftime('%Y-%m-%d %H:%M:%S')
                                    message = f'Snapmirror Lag Alert: {sourceClusterName}::{record["source"]["path"]} -> {clusterName}::{record["destination"]["path"]} has a lag time of {lagSeconds} seconds ({timeStr}) which is more than {maxLagTimePercent}% of its last scheduled update at {asciiTime}.'
                                    sendAlert(message, "WARNING")
                                    changedEvents=True
                                    event = {
                                        "index": uniqueIdentifier,
                                        "message": message,
                                        "refresh": eventResilience
                                    }
                                    events.append(event)

                if maxLagTime is not None and not processedLagTime:
                    if lagSeconds > maxLagTime:
                        uniqueIdentifier = record["uuid"] + "_" + maxLagTimeKey
                        if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                            timeStr = lagTimeStr(lagSeconds)
                            message = f'Snapmirror Lag Alert: {sourceClusterName}::{record["source"]["path"]} -> {clusterName}::{record["destination"]["path"]} has a lag time of {lagSeconds} seconds, or {timeStr} which is more than {maxLagTime}.'
                            sendAlert(message, "WARNING")
                            changedEvents=True
                            event = {
                                "index": uniqueIdentifier,
                                "message": message,
                                "refresh": eventResilience
                            }
                            events.append(event)

            if healthy is not None:
                if not healthy and not record["healthy"]: # Report on "not healthy" and the status is "not healthy"
                    uniqueIdentifier = record["uuid"] + "_" + healthyKey
                    if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                        message = f'Snapmirror Health Alert: {sourceClusterName}::{record["source"]["path"]} {clusterName}::{record["destination"]["path"]} has a status of {record["healthy"]}.'
                        for reason in record["unhealthy_reason"]:
                            message += "\n" + reason["message"]
                        sendAlert(message, "WARNING")
                        changedEvents=True
                        event = {
                            "index": uniqueIdentifier,
                            "message": message,
                            "refresh": eventResilience
                        }
                        events.append(event)

            if stalledTransferSeconds is not None:
                if record.get('transfer') is not None and record['transfer']['state'].lower() == "transferring":
                    transferUuid = record['transfer']['uuid']
                    bytesTransferred = record['transfer']['bytes_transferred']
                    prevRec =  getPreviousSMRecord(smRelationships, transferUuid) # This reset the "refresh" field if found.
                    if prevRec != None:
                        timeDiff=curTimeSeconds - prevRec["time"]
                        if prevRec['bytesTransferred'] == bytesTransferred:
                            if (curTimeSeconds - prevRec['time']) > stalledTransferSeconds:
                                uniqueIdentifier = record['uuid'] + "_" + "transfer"

                                if not eventExist(events, uniqueIdentifier):
                                    message = f"Snapmiorror transfer has stalled: {sourceClusterName}::{record['source']['path']} -> {clusterName}::{record['destination']['path']}."
                                    sendAlert(message, "WARNING")
                                    changedEvents=True
                                    event = {
                                        "index": uniqueIdentifier,
                                        "message": message,
                                        "refresh": eventResilience
                                    }
                                    events.append(event)
                        else:
                            prevRec['time'] = curTimeSeconds
                            prevRec['refresh'] = True
                            prevRec['bytesTransferred'] = bytesTransferred
                            updateRelationships = True
                    else:
                        prevRec = {
                            "time": curTimeSeconds,
                            "refresh": True,
                            "bytesTransferred": bytesTransferred,
                            "uuid": transferUuid
                        }
                        updateRelationships = True
                        smRelationships.append(prevRec)
        #
        # After processing the records, see if any SM relationships need to be removed.
        i = 0
        while i < len(smRelationships):
            if not smRelationships[i]["refresh"]:
                relationshipId = smRelationships[i].get("uuid")
                if relationshipId is None:
                    id="Old format"
                else:
                    id = relationshipId
                logger.debug(f'Deleting smRelationship: {id}')
                del smRelationships[i]
                updateRelationships = True
            else:
                i += 1
        #
        # If any of the SM relationships changed, save it.
        if(updateRelationships):
            s3Client.put_object(Key=config["smRelationshipsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(smRelationships).encode('UTF-8'))
        #
        # After processing the records, see if any events need to be removed.
        i = 0
        while i < len(events):
            if events[i]["refresh"] <= 0:
                logger.debug(f'Deleting event: {events[i]["message"]}')
                del events[i]
                changedEvents = True
            else:
                # If an event wasn't refreshed, then we need to save the new refresh count.
                if events[i]["refresh"] != eventResilience:
                    changedEvents = True
                i += 1
        #
        # If the events array changed, save it.
        if(changedEvents):
            s3Client.put_object(Key=config["smEventsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(events).encode('UTF-8'))
    else:
        logger.warning(f'API call to {endpoint} failed. HTTP status code {response.status}.')

################################################################################
# This function is used to check all the volume and aggregate utlization.
################################################################################
def processStorageUtilization(service):
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger

    changedEvents=False
    #
    # Get the saved events so we can ensure we are only reporting on new ones.
    try:
        data = s3Client.get_object(Key=config["storageEventsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert it sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            events = []
        else:
            raise err
    else:
        events = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Decrement the refresh field to know if any records have really gone away.
    for event in events:
        event["refresh"] -= 1
    #
    # Run the API call to get the physical storage used.
    endpoint = f'https://{config["OntapAdminServer"]}/api/storage/aggregates?fields=space&return_timeout=15'
    aggrResponse = http.request('GET', endpoint, headers=headers)
    if aggrResponse.status != 200:
        logger.error(f'API call to {endpoint} failed. HTTP status code {aggrResponse.status}.')
        aggrResponse = None
    #
    # Run the API call to get the volume information.
    endpoint = f'https://{config["OntapAdminServer"]}/api/storage/volumes?fields=space,files,svm,state&return_timeout=15'
    volumeResponse = http.request('GET', endpoint, headers=headers)
    if volumeResponse.status != 200:
        logger.error(f'API call to {endpoint} failed. HTTP status code {volumeResponse.status}.')
        volumeResponse = None
        volumeRecords = None
    else:
        volumeRecords = json.loads(volumeResponse.data).get("records")
        #
        # Now get the constituent volumes.
        endpoint = f'https://{config["OntapAdminServer"]}/api/storage/volumes?is_constituent=true&fields=space,files,svm,state&return_timeout=15'
        volumeResponse = http.request('GET', endpoint, headers=headers)
        if volumeResponse.status != 200:
            logger.error(f'API call to {endpoint} failed. HTTP status code {volumeResponse.status}.')
        else:
            volumeRecords.extend(json.loads(volumeResponse.data).get("records"))
    #
    # If both API calls failed, no point on continuing.
    if volumeResponse is None and aggrResponse is None:
        return

    for rule in service["rules"]:
        for key in rule.keys():
            lkey=key.lower()
            if lkey == "aggrwarnpercentused" or lkey == 'aggrcriticalpercentused':
                if aggrResponse is not None:
                    data = json.loads(aggrResponse.data)
                    for aggr in data["records"]:
                        if aggr["space"]["block_storage"]["used_percent"] >= rule[key]:
                            uniqueIdentifier = aggr["uuid"] + "_" + key
                            if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                alertType = 'Warning' if lkey == "aggrwarnpercentused" else 'Critical'
                                message = f'Aggregate {alertType} Alert: Aggregate {aggr["name"]} on {clusterName} is {aggr["space"]["block_storage"]["used_percent"]}% full, which is more or equal to {rule[key]}% full.'
                                sendAlert(message, "WARNING")
                                changedEvents = True
                                event = {
                                        "index": uniqueIdentifier,
                                        "message": message,
                                        "refresh": eventResilience
                                    }
                                logger.debug(event)
                                events.append(event)
            elif lkey == "volumewarnpercentused" or lkey == "volumecriticalpercentused":
                if volumeResponse is not None:
                    for record in volumeRecords:
                        if record["space"].get("percent_used"):
                            if record["space"]["percent_used"] >= rule[key]:
                                uniqueIdentifier = record["uuid"] + "_" + key
                                if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                    alertType = 'Warning' if lkey == "volumewarnpercentused" else 'Critical'
                                    message = f'Volume Usage {alertType} Alert: volume {record["svm"]["name"]}:{record["name"]} on {clusterName} is {record["space"]["percent_used"]}% full, which is more or equal to {rule[key]}% full.'
                                    sendAlert(message, "WARNING")
                                    changedEvents = True
                                    event = {
                                            "index": uniqueIdentifier,
                                            "message": message,
                                            "refresh": eventResilience
                                        }
                                    events.append(event)
            elif lkey == "volumewarnfilespercentused" or lkey == "volumecriticalfilespercentused":
                if volumeResponse is not None:
                    for record in volumeRecords:
                        #
                        # If a volume is offline, the API will not report the "files" information.
                        if record.get("files") is not None:
                            maxFiles = record["files"].get("maximum")
                            usedFiles = record["files"].get("used")
                            if maxFiles != None and usedFiles != None:
                                percentUsed = (usedFiles / maxFiles) * 100
                                if percentUsed >= rule[key]:
                                    uniqueIdentifier = record["uuid"] + "_" + key
                                    if not eventExist(events, uniqueIdentifier):
                                        alertType = 'Warning' if lkey == "volumewarnfilespercentused" else 'Critical'
                                        message = f"Volume File (inode) Usage {alertType} Alert: volume {record['svm']['name']}:{record['name']} on {clusterName} is using {percentUsed:.0f}% of it's inodes, which is more or equal to {rule[key]}% utilization."
                                        sendAlert(message, "WARNING")
                                        changedEvents = True
                                        event = {
                                                "index": uniqueIdentifier,
                                                "message": message,
                                                "refresh": eventResilience
                                            }
                                        events.append(event)
            elif lkey == "offline":
                for record in volumeRecords:
                    if rule[key] and record["state"].lower() == "offline":
                        uniqueIdentifier = f'{record["uuid"]}_{key}_{rule[key]}'
                        if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                            message = f"Volume Offline Alert: volume {record['svm']['name']}:{record['name']} on {clusterName} is offline."
                            sendAlert(message, "WARNING")
                            changedEvents=True
                            event = {
                                "index": uniqueIdentifier,
                                "message": message,
                                "refresh": eventResilience
                            }
                            events.append(event)
            else:
                message = f'Unknown storage alert type: "{key}".'
                logger.warning(message)
    #
    # After processing the records, see if any events need to be removed.
    i = 0
    while i < len(events):
        if events[i]["refresh"] <= 0:
            logger.debug(f'Deleting event: {events[i]["message"]}')
            del events[i]
            changedEvents = True
        else:
            # If an event wasn't refreshed, then we need to save the new refresh count.
            if events[i]["refresh"] != eventResilience:
                changedEvents = True
            i += 1
    #
    # If the events array changed, save it.
    if(changedEvents):
        s3Client.put_object(Key=config["storageEventsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(events).encode('UTF-8'))

################################################################################
# This function sends the message to the various alerting systems.
################################################################################
def sendAlert(message, severity):
    global config, snsClient, logger, cloudWatchClient

    if severity == "CRITICAL":
        logger.critical(message)
    elif severity == "ERROR":
        logger.error(message)
    elif severity == "WARNING":
        logger.warning(message)
    elif severity == "INFO":
        logger.info(message)
    elif severity == "DEBUG":
        logger.debug(message)
    else:
        logger.info(message)

    snsClient.publish(TopicArn=config["snsTopicArn"], Message=message, Subject=f'{severity}: Monitor ONTAP Services Alert for cluster {clusterName}')

    if cloudWatchClient is not None:
        #
        # Create a new log stream for the current day if it doesn't exist.
        dateStr = datetime.datetime.now().strftime("%Y-%m-%d")
        logStreamName = f'{clusterName}-monitor-ontap-services-{dateStr}'
        #
        # Don't ask me why AWS puts a ":*" at the end of the log group ARN, but they do.
        logGroupName = config["cloudWatchLogGroupArn"].split(":")[-2] if config["cloudWatchLogGroupArn"].endswith(":*") else config["cloudWatchLogGroupArn"].split(":")[-1]
        #
        # Check to see if the log stream already exists.
        logStreams = cloudWatchClient.describe_log_streams(logGroupName=logGroupName, logStreamNamePrefix=logStreamName)
        if len(logStreams["logStreams"]) == 0:
            cloudWatchClient.create_log_stream(
                logGroupName=logGroupName,
                logStreamName=logStreamName)
        #
        # Send the message to CloudWatch.
        cloudWatchClient.put_log_events(
            logGroupName=logGroupName,
            logStreamName=logStreamName,
            logEvents=[
                {
                    'timestamp': int(datetime.datetime.now().timestamp() * 1000),
                    'message': message
                },
            ]
        )

################################################################################
# This function is used to check utilization of quota limits.
################################################################################
def processQuotaUtilization(service):
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger

    changedEvents=False
    #
    # Get the saved events so we can ensure we are only reporting on new ones.
    try:
        data = s3Client.get_object(Key=config["quotaEventsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert it sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            events = []
        else:
            raise err
    else:
        events = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Decrement the refresh field to know if any records have really gone away.
    for event in events:
        event["refresh"] -= 1
    #
    # Run the API call to get the quota report.
    endpoint = f'https://{config["OntapAdminServer"]}/api/storage/quota/reports?fields=*&return_timeout=30'
    response = http.request('GET', endpoint, headers=headers)
    if response.status == 200:
        data = json.loads(response.data)
        for record in data["records"]:
            for rule in service["rules"]:
                for key in rule.keys():
                    lkey = key.lower() # Convert to all lower case so the key can be case insensitive.
                    if lkey == "maxquotainodespercentused":
                        #
                        # Since the quota report might not have the files key, and even if it does, it might not have
                        # the hard_limit_percent" key, need to check for their existencae first.
                        if(record.get("files") is not None and record["files"]["used"].get("hard_limit_percent") is not None and
                                record["files"]["used"]["hard_limit_percent"] > rule[key]):
                            uniqueIdentifier = str(record["index"]) + "_" + key
                            if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                if record.get("qtree") is not None:
                                    qtree=f' under qtree: {record["qtree"]["name"]} '
                                else:
                                    qtree=' '
                                if record.get("users") is not None:
                                    users=None
                                    for user in record["users"]:
                                        if users is None:
                                            users = user["name"]
                                        else:
                                            users += ',{user["name"]}'
                                    user=f'associated with user(s) "{users}" '
                                else:
                                    user=''
                                message = f'Quota Inode Usage Alert: Quota of type "{record["type"]}" on {record["svm"]["name"]}:/{record["volume"]["name"]}{qtree}{user}on {clusterName} is using {record["files"]["used"]["hard_limit_percent"]}% which is more than {rule[key]}% of its inodes.'
                                sendAlert(message, "WARNING")
                                changedEvents=True
                                event = {
                                        "index": uniqueIdentifier,
                                        "message": message,
                                        "refresh": eventResilience
                                        }
                                logger.debug(message)
                                events.append(event)
                    elif lkey == "maxhardquotaspacepercentused":
                        if(record.get("space") is not None and record["space"]["used"].get("hard_limit_percent") and
                                record["space"]["used"]["hard_limit_percent"] >= rule[key]):
                            uniqueIdentifier = str(record["index"]) + "_" + key
                            if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                if record.get("qtree") is not None:
                                    qtree=f' under qtree: {record["qtree"]["name"]} '
                                else:
                                    qtree=" "
                                if record.get("users") is not None:
                                    users=None
                                    for user in record["users"]:
                                        if users is None:
                                            users = user["name"]
                                        else:
                                            users += ',{user["name"]}'
                                    user=f'associated with user(s) "{users}" '
                                else:
                                    user=''
                                message = f'Quota Space Usage Alert: Hard quota of type "{record["type"]}" on {record["svm"]["name"]}:/{record["volume"]["name"]}{qtree}{user}on {clusterName} is using {record["space"]["used"]["hard_limit_percent"]}% which is more than {rule[key]}% of its allocaed space.'
                                sendAlert(message, "WARNING")
                                changedEvents=True
                                event = {
                                        "index": uniqueIdentifier,
                                        "message": message,
                                        "refresh": eventResilience
                                        }
                                logger.debug(message)
                                events.append(event)
                    elif lkey == "maxsoftquotaspacepercentused":
                        if(record.get("space") is not None and record["space"]["used"].get("soft_limit_percent") and
                                record["space"]["used"]["soft_limit_percent"] >= rule[key]):
                            uniqueIdentifier = str(record["index"]) + "_" + key
                            if not eventExist(events, uniqueIdentifier):  # This resets the "refresh" field if found.
                                if record.get("qtree") is not None:
                                    qtree=f' under qtree: {record["qtree"]["name"]} '
                                else:
                                    qtree=" "
                                if record.get("users") is not None:
                                    users=None
                                    for user in record["users"]:
                                        if users is None:
                                            users = user["name"]
                                        else:
                                            users += ',{user["name"]}'
                                    user=f'associated with user(s) "{users}" '
                                else:
                                    user=''
                                message = f'Quota Space Usage Alert: Soft quota of type "{record["type"]}" on {record["svm"]["name"]}:/{record["volume"]["name"]}{qtree}{user}on {clusterName} is using {record["space"]["used"]["soft_limit_percent"]}% which is more than {rule[key]}% of its allocaed space.'
                                sendAlert(message, "WARNING")
                                changedEvents=True
                                event = {
                                    "index": uniqueIdentifier,
                                    "message": message,
                                    "refresh": eventResilience
                                }
                                logger.debug(message)
                                events.append(event)
                    else:
                        message = f'Unknown quota matching condition type "{key}".'
                        logger.warning(message)
        #
        # After processing the records, see if any events need to be removed.
        i=0
        while i < len(events):
            if events[i]["refresh"] <= 0:
                logger.debug(f'Deleting event: {events[i]["message"]}')
                del events[i]
                changedEvents = True
            else:
                # If an event wasn't refreshed, then we need to save the new refresh count.
                if events[i]["refresh"] != eventResilience:
                    changedEvents = True
                i += 1
        #
        # If the events array changed, save it.
        if(changedEvents):
            s3Client.put_object(Key=config["quotaEventsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(events).encode('UTF-8'))
    else:
        logger.error(f'API call to {endpoint} failed. HTTP status code {response.status}.')

################################################################################
################################################################################
def processVserver(service):
    global config, s3Client, snsClient, http, headers, clusterName, logger

    changedEvents=False
    #
    # Get the saved events so we can ensure we are only reporting on new ones.
    try:
        data = s3Client.get_object(Key=config["vserverEventsFilename"], Bucket=config["s3BucketName"])
    except botocore.exceptions.ClientError as err:
        # If the error is that the object doesn't exist, then it will get created once an alert it sent.
        if err.response['Error']['Code'] == "NoSuchKey":
            events = []
        else:
            raise err
    else:
        events = json.loads(data["Body"].read().decode('UTF-8'))
    #
    # Decrement the refresh field to know if any records have really gone away.
    for event in events:
        event["refresh"] -= 1
    #
    # Consolidate the rules
    vserverState = None
    nfsProtocolState = None
    cifsProtocolState = None
    for rule in service["rules"]:
        for key in rule.keys():
            lkey = key.lower() # Convert to all lower case so the key can be case insensitive.
            if lkey == "vserverstate":
                vserverState = rule[key]
                vserverStateKey = key
            elif lkey == "nfsprotocolstate":
                nfsProtocolState = rule[key]
                nfsProtocolStateKey = key
            elif lkey == "cifsprotocolstate":
                cifsProtocolState = rule[key]
                cifsProtocolStateKey = key
    #
    # Check for any vservers that are down.
    if vserverState is not None and vserverState:
        #
        # Run the API call to get the vserver state for each vserver.
        endpoint = f'https://{config["OntapAdminServer"]}/api/svm/svms?fields=state&return_timeout=15'
        response = http.request('GET', endpoint, headers=headers)
        if response.status == 200:
            data = json.loads(response.data)
            for record in data["records"]:
                if record["state"].lower() != "running":
                    uniqueIdentifier = str(record["uuid"]) + "_" + vserverStateKey
                    if not eventExist(events, uniqueIdentifier):
                        message = f'SVM State Alert: SVM {record["name"]} on {clusterName} is not online.'
                        sendAlert(message, "WARNING")
                        changedEvents=True
                        event = {
                                "index": uniqueIdentifier,
                                "message": message,
                                "refresh": eventResilience
                                }
                        events.append(event)
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code {response.status}.')

    if nfsProtocolState is not None and nfsProtocolState:
        #
        # Run the API call to get the NFS protocol state for each vserver.
        endpoint = f'https://{config["OntapAdminServer"]}/api/protocols/nfs/services?fields=state&return_timeout=15'
        response = http.request('GET', endpoint, headers=headers)
        if response.status == 200:
            data = json.loads(response.data)
            for record in data["records"]:
                if record["state"].lower() != "online":
                    uniqueIdentifier = str(record["svm"]["uuid"]) + "_" + nfsProtocolStateKey
                    if not eventExist(events, uniqueIdentifier):
                        message = f'NFS Protocol State Alert: NFS protocol on {record["svm"]["name"]} on {clusterName} is not online.'
                        sendAlert(message, "WARNING")
                        changedEvents=True
                        event = {
                                "index": uniqueIdentifier,
                                "message": message,
                                "refresh": eventResilience
                                }
                        events.append(event) 
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code {response.status}.')

    if cifsProtocolState is not None and cifsProtocolState:
        #
        # Run the API call to get the NFS protocol state for each vserver.
        endpoint = f'https://{config["OntapAdminServer"]}/api/protocols/cifs/services?fields=enabled&return_timeout=15'
        response = http.request('GET', endpoint, headers=headers)
        if response.status == 200:
            data = json.loads(response.data)
            for record in data["records"]:
                if not record["enabled"]:
                    uniqueIdentifier = str(record["svm"]["uuid"]) + "_" + cifsProtocolStateKey
                    if not eventExist(events, uniqueIdentifier):
                        message = f'CIFS Protocol State Alert: CIFS protocol on {record["svm"]["name"]} on {clusterName} is not online.'
                        sendAlert(message, "WARNING")
                        changedEvents=True
                        event = {
                                "index": uniqueIdentifier,
                                "message": message,
                                "refresh": eventResilience
                                }
                        events.append(event) 
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code {response.status}.')

    #
    # After processing the records, see if any events need to be removed.
    i=0
    while i < len(events):
        if events[i]["refresh"] <= 0:
            logger.debug(f'Deleting event: {events[i]["message"]}')
            del events[i]
            changedEvents = True
        else:
            # If an event wasn't refreshed, then we need to save the new refresh count.
            if events[i]["refresh"] != eventResilience:
                changedEvents = True
            i += 1
    #
    # If the events array changed, save it.
    if(changedEvents):
        s3Client.put_object(Key=config["vserverEventsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(events).encode('UTF-8'))

################################################################################
# This function returns the index of the service in the conditions dictionary.
################################################################################
def getServiceIndex(targetService, conditions):

    i = 0
    while i < len(conditions["services"]):
        if conditions["services"][i]["name"] == targetService:
            return i
        i += 1

    return None

################################################################################
# This function builds a default matching conditions dictionary based on the
# environment variables passed in.
################################################################################
def buildDefaultMatchingConditions():
    #
    # Define global variables so we don't have to pass them to all the functions.
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger
    #
    # Define an empty matching conditions dictionary.
    conditions = { "services": [
        {"name": "systemHealth", "rules": []},
        {"name": "ems", "rules": []},
        {"name": "snapmirror", "rules": []},
        {"name": "storage", "rules": []},
        {"name": "quota", "rules": []},
        {"name": "vserver", "rules": []}
    ]}
    #
    # Now, add rules based on the environment variables.
    for name, value in os.environ.items():
        if name == "initialVersionChangeAlert":
            if value == "true":
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"versionChange": True})
            else:
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"versionChange": False})
        elif name == "initialFailoverAlert":
            if value == "true":
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"failover": True})
            else:
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"failover": False})
        elif name == "initialNetworkInterfacesAlert":
            if value == "true":
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"networkInterfaces": True})
            else:
                conditions["services"][getServiceIndex("systemHealth", conditions)]["rules"].append({"networkInterfaces": False})
        elif name == "initialEmsEventsAlert":
            if value == "true":
                conditions["services"][getServiceIndex("ems", conditions)]["rules"].append({"name": "", "severity": "error|alert|emergency", "message": "", "filter": ""})
        elif name == "initialSnapMirrorHealthAlert":
            if value == "true":
                conditions["services"][getServiceIndex("snapmirror", conditions)]["rules"].append({"Healthy": False})  # This is what it matches on, so it is interesting when the health is false.
            else:
                conditions["services"][getServiceIndex("snapmirror", conditions)]["rules"].append({"Healthy": True})
        elif name == "initialSnapMirrorLagTimeAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("snapmirror", conditions)]["rules"].append({"maxLagTime": value})
        elif name == "initialSnapMirrorLagTimePercentAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("snapmirror", conditions)]["rules"].append({"maxLagTimePercent": value})
        elif name == "initialSnapMirrorStalledAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("snapmirror", conditions)]["rules"].append({"stalledTransferSeconds": value})
        elif name == "initialFileSystemUtilizationWarnAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"aggrWarnPercentUsed": value})
        elif name == "initialFileSystemUtilizationCriticalAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"aggrCriticalPercentUsed": value})
        elif name == "initialVolumeUtilizationWarnAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"volumeWarnPercentUsed": value})
        elif name == "initialVolumeUtilizationCriticalAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"volumeCriticalPercentUsed": value})
        elif name == "initialVolumeFileUtilizationWarnAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"volumeWarnFilesPercentUsed": value})
        elif name == "initialVolumeFileUtilizationCriticalAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"volumeCriticalFilesPercentUsed": value})
        elif name == "initialVolumeOfflineAlert":
            if value == "true":
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"offline": True})
            else:
                conditions["services"][getServiceIndex("storage", conditions)]["rules"].append({"offline": False})
        elif name == "initialSoftQuotaUtilizationAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("quota", conditions)]["rules"].append({"maxSoftQuotaSpacePercentUsed": value})
        elif name == "initialHardQuotaUtilizationAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("quota", conditions)]["rules"].append({"maxHardQuotaSpacePercentUsed": value})
        elif name == "initialInodesQuotaUtilizationAlert":
            value = int(value)
            if value > 0:
                conditions["services"][getServiceIndex("quota", conditions)]["rules"].append({"maxQuotaInodesPercentUsed": value})
        elif name == "initialVserverStateAlert":
            if value == "true":
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"vserverState": True})
            else:
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"vserverState": False})
        elif name == "initialVserverNFSProtocolStateAlert":
            if value == "true":
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"nfsProtocolState": True})
            else:
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"nfsProtocolState": False})
        elif name == "initialVserverCIFSProtocolStateAlert":
            if value == "true":
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"cifsProtocolState": True})
            else:
                conditions["services"][getServiceIndex("vserver", conditions)]["rules"].append({"cifsProtocolState": False})

    return conditions

################################################################################
# This function is used to read in all the configuration parameters from the
# various places:
#   Environment Variables
#   Config File
#   Calculated
################################################################################
def readInConfig():
    #
    # Define global variables so we don't have to pass them to all the functions.
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger
    #
    # Define a dictionary with all the required variables so we can
    # easily add them and check for their existence.
    requiredEnvVariables = {
        "OntapAdminServer": None,
        "s3BucketName": None,
        "s3BucketRegion": None
        }

    optionalVariables = {
        "configFilename": None,
        "secretsManagerEndPointHostname": None,
        "snsEndPointHostname": None,
        "cloudWatchLogsEndPointHostname": None,
        "syslogIP": None,
        "cloudWatchLogGroupArn": None,
        "awsAccountId": None
        }

    filenameVariables = {
        "emsEventsFilename": None,
        "smEventsFilename": None,
        "smRelationshipsFilename": None,
        "conditionsFilename": None,
        "storageEventsFilename": None,
        "quotaEventsFilename": None,
        "systemStatusFilename": None,
        "vserverEventsFilename": None
        }

    config = {
        "snsTopicArn": None,
        "secretArn": None,
        "secretUsernameKey": None,
        "secretPasswordKey": None
        }
    config.update(filenameVariables)
    config.update(optionalVariables)
    config.update(requiredEnvVariables)
    #
    # Get the required, and any additional, paramaters from the environment.
    for var in config:
        config[var] = os.environ.get(var)
    #
    # Since the CloudFormation template will set the environment variables
    # to an empty string if someone doesn't provide a value, reset the
    # values back to None.
    for var in config:
        if config[var] == "":
            config[var] = None
    #
    # Since CloudFormation has to pass an ARN, get the Bucket name from it.
    # Too bad the bucket ARN doesn't include the region, like most (all?) the others do.
    if config["s3BucketName"] is None and os.environ.get("s3BucketArn") is not None:
        config["s3BucketName"] = os.environ.get("s3BucketArn").split(":")[-1]
    #
    # Check that required environmental variables are there.
    for var in requiredEnvVariables:
        if config[var] is None:
            raise Exception (f'\n\nMissing required environment variable "{var}".')
    #
    # Open a client to the s3 service.
    s3Client = boto3.client('s3', config["s3BucketRegion"])
    #
    # Calculate the config filename if it hasn't already been provided.
    defaultConfigFilename = config["OntapAdminServer"] + "-config"
    if config["configFilename"] is None:
        config["configFilename"] = defaultConfigFilename
    #
    # Process the config file if it exist.
    try:
        lines = s3Client.get_object(Key=config["configFilename"], Bucket=config["s3BucketName"])['Body'].iter_lines()
    except botocore.exceptions.ClientError as err:
        if err.response['Error']['Code'] != "NoSuchKey":
            raise err
        else:
            if config["configFilename"] != defaultConfigFilename:
                logger.warning(f"Warning, did not find file '{config['configFilename']}' in s3 bucket '{config['s3BucketName']}' in region '{config['s3BucketRegion']}'.")
    else:
        #
        # While iterating through the file, get rid of any "export ", comments, blank lines, or anything else that isn't key=value.
        for line in lines:
            line = line.decode('utf-8')
            if line[0:7] == "export ":
                line = line[7:]
            comment = line.split("#")
            line=comment[0].strip().replace('"', '')
            x = line.split("=")
            if len(x) == 2:
                (key, value) = line.split("=")
            key = key.strip()
            value = value.strip()
            if len(value) == 0:
                logger.warning(f"Warning, empty value for key '{key}'. Ignored.")
            else:
                #
                # Preserve any environment variables settings.
                if key in config:
                    if config[key] is None:
                        config[key] = value
                else:
                    logger.warning(f"Warning, unknown config parameter '{key}'.")
    #
    # Now, fill in the filenames for any that aren't already defined.
    for filename in filenameVariables:
        if config[filename] is None:
            config[filename] = config["OntapAdminServer"] + "-" + filename.replace("Filename", "")
    #
    # Define endpoints if alternates weren't provided.
    if config.get("secretArn") is not None and config["secretsManagerEndPointHostname"] is None:
        secretRegion = config["secretArn"].split(":")[3]
        config["secretsManagerEndPointHostname"] = f'secretsmanager.{secretRegion}.amazonaws.com'

    if config.get("snsTopicArn") is not None and config["snsEndPointHostname"] is None:
        snsRegion = config["snsTopicArn"].split(":")[3]
        config["snsEndPointHostname"] = f'sns.{snsRegion}.amazonaws.com'

    if config.get("cloudWatchLogGroupArn") is not None and config["cloudWatchLogsEndPointHostname"] is None:
        cloudWatchRegion = config["cloudWatchLogGroupArn"].split(":")[3]
        config["cloudWatchLogsEndPointHostname"] = f'logs.{cloudWatchRegion}.amazonaws.com'
    #
    # Now, check that all the configuration parameters have been set.
    for key in config:
        if config[key] is None and key not in optionalVariables:
            raise Exception(f'\n\nMissing configuration parameter "{key}".\n\n')

################################################################################
# Main logic
################################################################################
def lambda_handler(event, context):
    #
    # Define global variables so we don't have to pass them to all the functions.
    global config, s3Client, snsClient, http, headers, clusterName, clusterVersion, logger, cloudWatchClient, clusterTimezone
    #
    # Set up logging.
    logger = logging.getLogger("mon_fsxn_service")
    if lambdaFunction:
        logger.setLevel(logging.INFO)       # Anything at this level and above this get logged.
    else: # Assume we are running in a test environment.
        logger.setLevel(logging.DEBUG)      # Anything at this level and above this get logged.
        formatter = logging.Formatter(
                fmt="%(name)s:%(funcName)s - Level:%(levelname)s - Message:%(message)s",
                datefmt="%Y-%m-%d %H:%M:%S"
            )
        loggerscreen = logging.StreamHandler()
        loggerscreen.setFormatter(formatter)
        logger.addHandler(loggerscreen)
    #
    # Read in the configuraiton.
    readInConfig()   # This defines the s3Client variable.
    #
    # Set up the logger to log to a file and to syslog.
    if config["syslogIP"] is not None:
        #
        # Due to a bug with the SysLogHandler() of not sending proper framing with a message
        # when using TCP (it should end it with a LF and not a NUL like it does now) you must add
        # an additional frame delimiter to the receiving syslog server. With rsyslog, you add
        # a AddtlFrameDelimiter="0" directive to the "input()" line where they have it listen
        # to a TCP port. For example:
        #
        #  # provides TCP syslog reception
        #  module(load="imtcp")
        #  input(type="imtcp" port="514" AddtlFrameDelimiter="0")
        #
        # Because of this bug, I am going to stick with UDP, the default protocol used by
        # the syslog handler. If TCP is required, then the above changes will have to be made
        # to the syslog server. Or, the program will have to handle closing and opening the
        # connection for each message. The following will do that:
        #    handler.flush()
        #    handler.close()
        #    logger.removeHandler(handler)
        #    handler = logging.handlers.SysLogHandler(facility=SysLogHandler.LOG_LOCAL0, address=(syslogIP, 514), socktype=socket.SOCK_STREAM)
        #    handler.setFormatter(formatter)
        #    logger.addHandler(handler)
        #
        # You might get away with a simple handler.open() after the close(), without having to
        # remove and add the handler. I didn't test that.
        handler = logging.handlers.SysLogHandler(facility=SysLogHandler.LOG_LOCAL0, address=(config["syslogIP"], 514))
        formatter = logging.Formatter(
                fmt="%(name)s:%(funcName)s - Level:%(levelname)s - Message:%(message)s",
                datefmt="%Y-%m-%d %H:%M:%S"
            )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    #
    # Create a Secrets Manager client.
    session = boto3.session.Session()
    secretRegion = config["secretArn"].split(":")[3]
    client = session.client(service_name='secretsmanager', region_name=secretRegion, endpoint_url=f'https://{config["secretsManagerEndPointHostname"]}')
    #
    # Get the username and password of the ONTAP/FSxN system.
    secretsInfo = client.get_secret_value(SecretId=config["secretArn"])
    secrets = json.loads(secretsInfo['SecretString'])
    if secrets.get(config['secretUsernameKey']) is None:
        logger.critical(f'Error, "{config["secretUsernameKey"]}" not found in secret "{config["secretArn"]}".')
        return

    if secrets.get(config['secretPasswordKey']) is None:
        logger.critical(f'Error, "{config["secretPasswordKey"]}" not found in secret "{config["secretArn"]}".')
        return

    username = secrets[config['secretUsernameKey']]
    password = secrets[config['secretPasswordKey']]
    #
    # Create clients to the other AWS services we will be using.
    #s3Client = boto3.client('s3', config["s3BucketRegion"])  # Defined in readInConfig()
    snsRegion = config["snsTopicArn"].split(":")[3]
    snsClient = boto3.client('sns', region_name=snsRegion, endpoint_url=f'https://{config["snsEndPointHostname"]}')
    cloudWatchClient = None
    if config["cloudWatchLogGroupArn"] is not None:
        cloudWatchRegion = config["cloudWatchLogGroupArn"].split(":")[3]
        cloudWatchClient = boto3.client('logs', region_name=cloudWatchRegion, endpoint_url=f'https://{config["cloudWatchLogsEndPointHostname"]}')
    #
    # Create a http handle to make ONTAP/FSxN API calls with.
    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)  # pylint: disable=E1123
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Get the conditions we know what to alert on.
    try:
        data = s3Client.get_object(Key=config["conditionsFilename"], Bucket=config["s3BucketName"])
        matchingConditions = json.loads(data["Body"].read().decode('UTF-8'))
    except botocore.exceptions.ClientError as err:
        if err.response['Error']['Code'] != "NoSuchKey":
            logger.error(f'Error, could not retrieve configuration file {config["conditionsFilename"]} from: s3://{config["s3BucketName"]}.\nBelow is additional information:')
            raise err
        else:
            matchingConditions = buildDefaultMatchingConditions()
            s3Client.put_object(Key=config["conditionsFilename"], Bucket=config["s3BucketName"], Body=json.dumps(matchingConditions, indent=4).encode('UTF-8'))
    except json.decoder.JSONDecodeError as err:
        logger.error(f'Error, could not decode JSON from configuration file "{config["conditionsFilename"]}". The error message from the decoder:\n{err}\n')
        return

    if(checkSystem()):
        #
        # Loop on all the configured ONTAP services we want to check on.
        for service in matchingConditions["services"]:
            if service["name"].lower() == "systemhealth":
                checkSystemHealth(service)
            elif service["name"].lower() == "ems":
                processEMSEvents(service)
            elif (service["name"].lower() == "snapmirror"):
                processSnapMirrorRelationships(service)
            elif service["name"].lower() == "storage":
                processStorageUtilization(service)
            elif service["name"].lower() == "quota":
                processQuotaUtilization(service)
            elif service["name"].lower() == "vserver":
                processVserver(service)
            else:
                logger.warning(f'Unknown service "{service["name"]}".')
    return

if os.environ.get('AWS_LAMBDA_FUNCTION_NAME') is None:
    lambdaFunction = False
    lambda_handler(None, None)
else:
    lambdaFunction = True
