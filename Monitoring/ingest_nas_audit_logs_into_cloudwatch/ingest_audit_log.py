#!/bin/python3
#
################################################################################
# This script is used to ingest all the NAS audit logs from all the FSx for
# ONTAP File Systems from the specified volume into a specified CloudWatch log
# group. It will create a log stream for each FSxN audit logfile it finds.
# It will attempt to process every FSxN within the region. It leverage AWS
# secrets manager to get the credentials for the fsxadmin user on each FSxNs.
# It will store the last read file for each FSxN in the specified S3 bucket so
# that it will not process the same file twice. It will skip any FSxN file
# system that it doesn't have credentials for. It will also skip any FSxN file
# system that doesn't have the specified volume.
#
# It assumes:
#  - That the administrator username is 'fsxadmin'.
#  - That the audit log files will be named in the following format:
#      audit_vserver_D2024-09-24-T13-00-03_0000000000.xml
#    Where 'vserver' is the vserver name.
#
################################################################################
#
from requests_toolbelt.multipart import decoder
import urllib3
import datetime
import xmltodict
import os
import json
from urllib3.util import Retry
import boto3
import botocore

################################################################################
# You can configure this script by either setting the following variables in
# code below, or by setting environment variables with the same name.
################################################################################
#
# The secretARNs contains the secretARNs for all the FSxNs you want to process.
# Unlike the rest of the variables this one cannot be set via an environment
# variable. There are three options to populate the dictionary:
#
# 1. Create a 'secretARNs' variable by un-commenting out the code segment
#    below that defines dictionary with the following structure:
#
# secretARNs =  {
#     "<fsId-1>": "<secretARN>",
#     "<fsId-2>": "<secretARN>",
#     "<fsId-3>": "<secretARN>"
#   }
#
# 2. Set the fsxnSecretARNsFile variable to the name of a file in the s3
#    bucket that contains the secretARNs.
#
# fsxnSecretARNsFile=
#
#  The format of that file should be:
#
# <fsId-1>=<secretARN>
# <fsId-2>=<secretARN>
#
# 3. Set the fileSystem1ID, fileSystem2ID, fileSystem3ID, fileSystem4ID, and
#    fileSystem5ID variables to the fsId of the FSxN file systems. Then set
#    the fileSystem1SecretARN, fileSystem2SecretARN, fileSystem3SecretARN,
#    fileSystem4SecretARN, and fileSystem5SecretARN variables to the
#    secretARNs for the FSxN file systems. Empty, or variables not defined
#    will be ignored. Note that if fsxnSecretARNsFile is set, then these
#    variables will be ignored.
#
# fileSystem1ID = 
# fileSystem1SecretARN =
# fileSystem2ID = 
# fileSystem2SecretARN =
# fileSystem3ID = 
# fileSystem3SecretARN =
# fileSystem4ID = 
# fileSystem4SecretARN =
# fileSystem5ID = 
# fileSystem5SecretARN =
#
# *NOTE*: Each secret should have two keys: 'username' and 'password' set to the
# appropriate values.
#
# Specify what s3 bucket to use to store the last read file and potentially
# the audit log files and the secretsARNs file.
# s3BucketRegion = "us-west-2"
# s3BucketName = ""
#
# The name of the "last read" file.
# statsName = "lastFileRead"
#
# The region to process the FSxNs in.
# fsxRegion = "us-west-2"
#
# The name of the volume that holds the audit logs. Assumed to be the same on
# vservers.
# volumeName = "audit_logs"
#
# The name of the vserver that holds the audit logs. Assumed to be the same on
# all FSxNs.
# *NOTE*:The program has been updated to loop on all the vservers within an FSxN
#        filesystem and not just the one set here. This variable is now used
#        so it can update the lastFireRead stats file to conform to the new
#        format that includes the vserver as part of the structure.
# vserverName = "fsx"
#
# The CloudWatch log group to store the audit logs in. It must already exist.
# logGroupName = "/fsx/audit_logs"
#
# If you want the program to copy all the raw audit files into the S3 bucket,
# then set this to the string "true". It will be converted to a boolean later.
# copyToS3 = "true"

################################################################################
# This function returns the epoch time from the filename. It assumes the
# filename is in the format of:
#   audit_fsx_D2024-09-24-T13-00-03_0000000000.xml
################################################################################
def getEpoch(filename):
    dateStr = filename.split('_')[2][1:]
    year = int(dateStr.split('-')[0])
    month = int(dateStr.split('-')[1])
    day = int(dateStr.split('-')[2])

    hour = int(dateStr.split('-')[3][1:])
    minute = int(dateStr.split('-')[4])
    second = int(dateStr.split('-')[5])

    return datetime.datetime(year, month, day, hour, minute, second).timestamp()

################################################################################
# This function copies a file from the FSxN file system, using the ONTAP
# APIs, and then calls the ingestAuditFile function to upload the audit
# log entires to the CloudWatch log group.
################################################################################
def readFile(ontapAdminServer, headers, volumeUUID, filePath):
    global http
    #
    # Create the tempoary file to hold the contents from the ONTAP/FSxN file.
    tmpFileName = "/tmp/testout"
    f = open(tmpFileName, "wb")
    #
    # Number of bytes to read for each API call.
    blockSize=1024*1024

    failed = False
    bytesRead = 0
    requestSize = 1   # Set to > 0 to start the loop.
    while requestSize > 0:
        endpoint = f'https://{ontapAdminServer}/api/storage/volumes/{volumeUUID}/files/{filePath}?length={blockSize}&byte_offset={bytesRead}'
        response = http.request('GET', endpoint, headers=headers, timeout=5.0)
        if response.status == 200:
            bytesRead += blockSize
            data = response.data
            #
            # Get the multipart boundary separator from the first part of the file.
            boundary = data[4:20].decode('utf-8')
            #
            # Get MultipartDecoder to decode the data.
            contentType = f"multipart/form-data; boundary={boundary}"
            multipart_data = decoder.MultipartDecoder(data, contentType)
            #
            # The first part returned from ONTAP contains the amount of data in the response. When it is 0, we have read the entire file.
            firstPart = True
            for part in multipart_data.parts:
                if(firstPart):
                    requestSize = int(part.text)
                    firstPart = False
                else:
                    f.write(part.content)
        else:
            print(f'Warning: API call to {endpoint} failed. HTTP status code: {response.status}.')
            break

    f.close()
    if failed:
        os.remove(tmpFileName)
        return None
    else:
        return tmpFileName
        #
        # Upload the audit events to CloudWatch.

################################################################################
# This functions converts the timestamp from the XML file to a timestamp in
# milliseconds. An example format of the time is:
#    2024-09-22T21:05:27.263864000Z
################################################################################
def getTimestampFromEvent(event):

    year = int(event['System']['TimeCreated']['@SystemTime'].split('-')[0])
    month = int( event['System']['TimeCreated']['@SystemTime'].split('-')[1])
    day =  int(event['System']['TimeCreated']['@SystemTime'].split('-')[2].split('T')[0])
    hour =  int(event['System']['TimeCreated']['@SystemTime'].split('T')[1].split(':')[0])
    minute =  int(event['System']['TimeCreated']['@SystemTime'].split('T')[1].split(':')[1])
    second =  int(event['System']['TimeCreated']['@SystemTime'].split('T')[1].split(':')[2].split('.')[0])
    msecond = event['System']['TimeCreated']['@SystemTime'].split('T')[1].split(':')[2].split('.')[1].split('Z')[0]
    t = datetime.datetime(year, month, day, hour, minute, second, tzinfo=datetime.timezone.utc).timestamp()
    #
    # Convert the timestep from a float in seconds to an integer in milliseconds.
    msecond = int(msecond)/(10 ** (len(msecond) - 3))
    t = int(t * 1000 + msecond)
    return t

################################################################################
# This puts the CloudWatch event into the CloudWatch log stream.
################################################################################
def putEventInCloudWatch(cwEvents, auditLogName):
    global cwLogsClient, config

    response = cwLogsClient.put_log_events(logGroupName=config['logGroupName'], logStreamName=auditLogName, logEvents=cwEvents)
    if response.get('rejectedLogEventsInfo') != None:
        if response['rejectedLogEventsInfo'].get('tooNewLogEventStartIndex') is not None:
            print(f"Warning: Too new log event start index: {response['rejectedLogEventsInfo']['tooNewLogEventStartIndex']}")
        if response['rejectedLogEventsInfo'].get('tooOldLogEventEndIndex') is not None:
            print(f"Warning: Too old log event end index: {response['rejectedLogEventsInfo']['tooOldLogEventEndIndex']}")

################################################################################
# This function returns a CloudWatch event from the XML audit log event.
################################################################################
def createCWEvent(event):
    # ObjectServer: Always just seems to be: 'Security'.
    # HandleID: Is some odd string of numbers.
    # InformationRequested: A verbose string of information.
    # AccessList: A string of numbers that I'm not sure what they represent.
    # AccessMask: A number that represent the access mask.
    # DesiredAccess: A verbose list of strings represent the desired access.
    # Attributes: A verbose list of strings representing the attributes.
    # DirHandleID: A string of numbers that I'm not sure what they represent.
    # SearchFilter: Always seems to be null.
    # SearchPattern: Always seems to be set to "Not Present".
    # SubjectPort: Just the TCP port that the user came in on.
    # OldDirHandle and NewDirHandle: Are the UUIDs of the directory. The OldPath and NewPath are human readable.
    ignoredDataFields = ["ObjectServer", "HandleID", "InformationRequested", "AccessList", "AccessMask", "DesiredAccess", "Attributes", "DirHandleID", "SearchFilter", "SearchPattern", "SubjectPort", "OldDirHandle", "NewDirHandle"]

    eventTimestamp = getTimestampFromEvent(event)
    #
    # Build the message to send to CloudWatch.
    cwData  = f"Date={event['System']['TimeCreated']['@SystemTime']}, "
    cwData += f"Event={event['System']['EventName'].replace(' ', '-')}, " # Replace spaces with dashes.
    cwData += f"fs={event['System']['Computer'].split('/')[0]}, "
    cwData += f"svm={event['System']['Computer'].split('/')[1]}, "
    cwData += f"Result={event['System']['Result'].replace(' ', '-')}"     # Replace spaces with dashes.
    #
    # Add the data fields to the message. Some fields are ignored. Some required special handling.
    for data in event['EventData']['Data']:
        if data['@Name'] not in ignoredDataFields:
            if data['@Name'] == 'SubjectIP':
                cwData += f", IP={data['#text']}"
            elif data['@Name'] == 'SubjectUnix':
                cwData += f", UnixID={data['@Uid']}, GroupID={data['@Gid']}"
            elif data['@Name'] == 'SubjectUserSid':
                cwData += f", UserSid={data['#text']}"
            elif data['@Name'] == 'SubjectUserName':
                cwData += f", UserName={data['#text']}"
            elif data['@Name'] == 'SubjectDomainName':
                cwData += f", Domain={data['#text']}"
            elif data['@Name'] == 'ObjectName' or data['@Name'] == 'FileName':
                cwData += f", volume={data['#text'].split(';')[0].replace('(', '').replace(')', '')}, name={data['#text'].split(';')[1]}"
            elif data['@Name'] == 'InformationSet':
                if data.get('#text') == None:
                    cwData += ", InformationSet=Null"
                else:
                    cwData += f", InformationSet={data['#text']}"
            else: # Assume the rest of the fields don't need special handling.
                cwData += f", {data['@Name']}={data['#text']}"

    return {'timestamp': eventTimestamp, 'message': cwData}

################################################################################
# This function uploads the audit log events stored in XML format to a
# CloudWatch log stream.
################################################################################
def ingestAuditFile(auditLogPath, auditLogName):
    global cwLogsClient, config
    #
    # Convert the XML audit log file into a dictionary.
    f = open(auditLogPath, 'r')
    data = f.read()
    dictData = xmltodict.parse(data)

    if dictData.get('Events') == None or dictData['Events'].get('Event') == None:
        print(f"Info: No events found in {auditLogName}.")
        return
    #
    # Ensure the logstream exists.
    try:
        cwLogsClient.create_log_stream(logGroupName=config['logGroupName'], logStreamName=auditLogName)
    except cwLogsClient.exceptions.ResourceAlreadyExistsException:
        #
        # This really shouldn't happen, since we should only be processing
        # each file once, but during testing it happens all the time.
        print(f"Info: Log stream {auditLogName} already exists.")
    #
    # If there is only one event, then the dict['Events']['Event'] will be a
    # dictionary, otherwise it will be a list of dictionaries.
    if isinstance(dictData['Events']['Event'], list):
        #
        # Make sure not to span more than 24 hours of events in a single put_log_events call.
        firstEventTimestamp = getTimestampFromEvent(dictData['Events']['Event'][0])
        cwEvents = []
        for event in dictData['Events']['Event']:
            currentEventTimestamp = getTimestampFromEvent(event)
            if currentEventTimestamp - firstEventTimestamp > 79200000:  # 23 hours and 55 minutes in milliseconds.
                print("Info: Putting 24 hours of events.")
                putEventInCloudWatch(cwEvents, auditLogName)
                cwEvents = []
                firstEventTimestamp = currentEventTimestamp

            cwEvents.append(createCWEvent(event))
            if len(cwEvents) == 5000:  # The real maximum is 10000 events, but there is also a size limit, so we will use 5000.
                print("Info: Putting 5000 events")
                putEventInCloudWatch(cwEvents, auditLogName)
                cwEvents = []
                firstEventTimestamp = currentEventTimestamp
    else:
        cwEvents = [createCWEvent(dictData['Events']['Event'])]

    if len(cwEvents) > 0:
        print(f"Info: Putting {len(cwEvents)} events")
        putEventInCloudWatch(cwEvents, auditLogName)

################################################################################
# This function checks that all the required configuration variables are set.
################################################################################
def checkConfig():
    global config, s3Client, secretARNs

    config = {
        'volumeName': volumeName if 'volumeName' in globals() else None,               # pylint: disable=E0602
        'logGroupName': logGroupName if 'logGroupName' in globals() else None,         # pylint: disable=E0602
        'fsxRegion': fsxRegion if 'fsxRegion' in globals() else None,                  # pylint: disable=E0602
        's3BucketRegion': s3BucketRegion if 's3BucketRegion' in globals() else None,   # pylint: disable=E0602
        's3BucketName': s3BucketName if 's3BucketName' in globals() else None,         # pylint: disable=E0602
        'statsName': statsName if 'statsName' in globals() else None,                  # pylint: disable=E0602
        'copyToS3': copyToS3 if 'copyToS3' in globals() else None,                     # pylint: disable=E0602
        'fsxnSecretARNsFile': fsxnSecretARNsFile if 'fsxnSecretARNsFile' in globals() else None,  # pylint: disable=E0602
        'fileSystem1ID': fileSystem1ID if 'fileSystem1ID' in globals() else None,      # pylint: disable=E0602
        'fileSystem2ID': fileSystem2ID if 'fileSystem2ID' in globals() else None,      # pylint: disable=E0602
        'fileSystem3ID': fileSystem3ID if 'fileSystem3ID' in globals() else None,      # pylint: disable=E0602
        'fileSystem4ID': fileSystem4ID if 'fileSystem4ID' in globals() else None,      # pylint: disable=E0602
        'fileSystem5ID': fileSystem5ID if 'fileSystem5ID' in globals() else None,      # pylint: disable=E0602
        'fileSystem1SecretARN': fileSystem1SecretARN if 'fileSystem1SecretARN' in globals() else None,  # pylint: disable=E0602
        'fileSystem2SecretARN': fileSystem2SecretARN if 'fileSystem2SecretARN' in globals() else None,  # pylint: disable=E0602
        'fileSystem3SecretARN': fileSystem3SecretARN if 'fileSystem3SecretARN' in globals() else None,  # pylint: disable=E0602
        'fileSystem4SecretARN': fileSystem4SecretARN if 'fileSystem4SecretARN' in globals() else None,  # pylint: disable=E0602
        'fileSystem5SecretARN': fileSystem5SecretARN if 'fileSystem5SecretARN' in globals() else None   # pylint: disable=E0602
    }
    optionalConfig = ['copyToS3', 'fsxnSecretARNsFile', 'fileSystem1ID',
                      'fileSystem2ID', 'fileSystem3ID', 'fileSystem4ID',
                      'fileSystem5ID', 'fileSystem1SecretARN', 'fileSystem2SecretARN',
                      'fileSystem3SecretARN', 'fileSystem4SecretARN', 'fileSystem5SecretARN']

    for item in config:
        if config[item] == None:
            config[item] = os.environ.get(item)
        if item not in optionalConfig and config[item] == None:
            raise Exception(f"{item} is not set.")

    if config['copyToS3'] == None:
        config['copyToS3'] = False
    else:
        config['copyToS3'] = config['copyToS3'].lower() == 'true'
    #
    # To be backwards compatible, load the vserverName.
    config['vserverName'] = vserverName if 'vserverName' in globals() else os.environ.get('vserverName')  # pylint: disable=E0602
    #
    # Create a S3 client.
    s3Client = boto3.client('s3', config['s3BucketRegion'])
    #
    # Define the secretsARNs dictionary if it hasn't already been defined.
    if 'secretARNs' not in globals():
        secretARNs = {}
    #
    # If the fsxnSecretARNsFile is set, then read the file from S3 and populate the secretARNs dictionary.
    if config['fsxnSecretARNsFile'] is not None and config['fsxnSecretARNsFile'] != '':
        try:
            response = s3Client.get_object(Bucket=config['s3BucketName'], Key=config['fsxnSecretARNsFile'])
        except botocore.exceptions.ClientError as err:
            raise Exception(f"Unable to open parameter file with secrets '{config['fsxnSecretARNsFile']}' from S3 bucket '{config['s3BucketName']}': {err}")
        else:
            for line in response['Body'].iter_lines():
                line = line.decode('utf-8')
                line = line.strip()
                if line.startswith('#'):
                    continue
                if line == '':
                    continue
                fsId, secretArn = line.split('=')
                secretARNs[fsId.strip()] = secretArn.strip()
    else:
        if config['fileSystem1ID'] is not None and config['fileSystem1SecretARN'] is not None:
            secretARNs[config['fileSystem1ID']] = config['fileSystem1SecretARN']
        if config['fileSystem2ID'] is not None and config['fileSystem2SecretARN'] is not None:
            secretARNs[config['fileSystem2ID']] = config['fileSystem2SecretARN']
        if config['fileSystem3ID'] is not None and config['fileSystem3SecretARN'] is not None:
            secretARNs[config['fileSystem3ID']] = config['fileSystem3SecretARN']
        if config['fileSystem4ID'] is not None and config['fileSystem4SecretARN'] is not None:
            secretARNs[config['fileSystem4ID']] = config['fileSystem4SecretARN']
        if config['fileSystem5ID'] is not None and config['fileSystem5SecretARN'] is not None:
            secretARNs[config['fileSystem5ID']] = config['fileSystem5SecretARN']

################################################################################
# This is the main function that checks that everything is configured correctly
# and then processes all the FSxNs.
################################################################################
def lambda_handler(event, context):     # pylint: disable=W0613
    global http, cwLogsClient, config, s3Client, secretARNs
    #
    # Check that we have all the configuration variables we need.
    checkConfig()
    #
    # Create a Secrets Manager client.
    session = boto3.session.Session()
    #
    # Create a S3 client.
    # Created in the checkCofnig function.
    # s3Client = boto3.client('s3', config['s3BucketRegion'])
    #
    # Create a FSx client.
    fsxClient = boto3.client('fsx', config['fsxRegion'])
    #
    # Create a CloudWatch client.
    cwLogsClient = boto3.client('logs', config['fsxRegion'])
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)  # pylint: disable=E1123
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Get a list of FSxNs in the region.
    fsxNs = []   # Holds the FQDN of the FSxNs management ports.
    fsxResponse = fsxClient.describe_file_systems()
    for fsx in fsxResponse['FileSystems']:
        fsxNs.append(fsx['OntapConfiguration']['Endpoints']['Management']['DNSName'])
    #
    # Make sure to get them all since the response is paginated.
    while fsxResponse.get('NextToken') != None:
        fsxResponse = fsxClient.describe_file_systems(NextToken=fsxResponse['NextToken'])
        for fsx in fsxResponse['FileSystems']:
            fsxNs.append(fsx['OntapConfiguration']['Endpoints']['Management']['DNSName'])
    #
    # Get the last read stats file.
    try:
        response = s3Client.get_object(Bucket=config['s3BucketName'], Key=config['statsName'])
    except botocore.exceptions.ClientError as err:
        #
        # If the error is that the object doesn't exist, then this must be the
        # first time this script has run so create an empty lastFileRead.
        if err.response['Error']['Code'] == "NoSuchKey":
            lastFileRead = {}
        else:
            raise err
    else:
        lastFileRead = json.loads(response['Body'].read().decode('utf-8'))
    #
    # Process each FSxN.
    for fsxn in fsxNs:
        fsId = fsxn.split('.')[1]
        #
        # Since the format of the lastReadFile structure has changed, we need to update it.
        if lastFileRead.get(fsxn) is not None and config['vserverName'] is not None:
            if type(lastFileRead[fsxn]) is float:                                  # Old format
                lastFileRead[fsxn] = {config['vserverName']: lastFileRead[fsxn]}   # New format
        #
        # Get the credentials.
        if secretARNs.get(fsId) is not None:
            #
            # Get the username and password of the ONTAP/FSxN system.
            try:
                secretsClient = session.client(service_name='secretsmanager', region_name=secretARNs[fsId].split(':')[3])
                secretsInfo = secretsClient.get_secret_value(SecretId=secretARNs[fsId])
                secret = json.loads(secretsInfo['SecretString'])
                if secret.get('username') is None or secret.get('password') is None:
                    print(f"Warning: The 'username' or 'password' keys were not found in the secret for '{fsId}' in the secretARN '{secretARNs[fsId]}'.")
                    continue
                username = secret['username']
                password = secret['password']
                secretsClient.close()
            except botocore.exceptions.ClientError as err:
                print(f"Warning: Unable to retrieve the credentials for '{fsId}' using the secretARN '{secretARNs[fsId]}'. {err}")
                continue
        else:
            print(f'Warning: No secret ARN was found for {fsId}.')
            continue
        #
        # Create a header with the basic authentication.
        auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
        headersDownload = { **auth, 'Accept': 'multipart/form-data' }
        headersQuery = { **auth }
        #
        # Get the list of SVMs on the FSxN.
        endpoint = f"https://{fsxn}/api/svm/svms?return_timeout=4"
        response = http.request('GET', endpoint, headers=headersQuery, timeout=5.0)
        if response.status == 200:
            svmsData = json.loads(response.data.decode('utf-8'))
            numSvms = svmsData['num_records']
            #
            # Loop over all the SVMs.
            while numSvms > 0:
                for record in svmsData['records']:
                    vserverName = record['name']
                    #
                    # Get the volume UUID for the audit_logs volume.
                    volumeUUID = None
                    endpoint = f"https://{fsxn}/api/storage/volumes?name={config['volumeName']}&svm={vserverName}"
                    response = http.request('GET', endpoint, headers=headersQuery, timeout=5.0)
                    if response.status == 200:
                        data = json.loads(response.data.decode('utf-8'))
                        if data['num_records'] > 0:
                            volumeUUID = data['records'][0]['uuid']  # Since we specified the volume, and vserver name, there should only be one record.

                    if volumeUUID == None:
                        print(f"Warning: Volume {config['volumeName']} not found for {fsId} under SVM: {vserverName}.")
                        continue
                    #
                    # Get all the files in the volume that match the audit file pattern.
                    endpoint = f"https://{fsxn}/api/storage/volumes/{volumeUUID}/files?name=audit_{vserverName}_D*.xml&order_by=name%20asc&fields=name"
                    response = http.request('GET', endpoint, headers=headersQuery, timeout=5.0)
                    data = json.loads(response.data.decode('utf-8'))
                    if data.get('num_records') == 0:
                        print(f"Warning: No XML audit log files found on FsID: {fsId}; SvmID: {vserverName}; Volume: {config['volumeName']}.")
                        continue

                    for file in data['records']:
                        filePath = file['name']
                        if lastFileRead.get(fsxn) is None or lastFileRead[fsxn].get(vserverName) is None or getEpoch(filePath) > lastFileRead[fsxn][vserverName]:
                            localFileName = readFile(fsxn, headersDownload, volumeUUID, filePath)
                            if localFileName is not None:
                                if config['copyToS3']:
                                    s3Client.upload_file(localFileName, config['s3BucketName'], filePath)
                                ingestAuditFile(localFileName, filePath)
                                if lastFileRead.get(fsxn) is None:
                                    lastFileRead[fsxn] = {vserverName: getEpoch(filePath)}
                                else:
                                    lastFileRead[fsxn][vserverName] = getEpoch(filePath)
                                s3Client.put_object(Key=config['statsName'], Bucket=config['s3BucketName'], Body=json.dumps(lastFileRead).encode('UTF-8'))
                                os.remove(localFileName)
                #
                # Get the next set of SVMs.
                if svmsData['_links'].get('next') != None:
                    endpoint = f"https://{fsxn}{svmsData['_links']['next']['href']}"
                    response = http.request('GET', endpoint, headers=headersQuery, timeout=5.0)
                    if response.status == 200:
                        svmsData = json.loads(response.data.decode('utf-8'))
                        numSvms = svmsData['num_records']
                    else:
                        print(f"Warning: API call to {endpoint} failed. HTTP status code: {response.status}.")
                        break # Break out of the for all SVMs loop. Maybe the call to the next FSxN will work.
                else:
                    numSvms = 0
        else:
            print(f"Warning: API call to {endpoint} failed. HTTP status code: {response.status}.")
            break # Break out of the for all FSxNs loop.
#
# If this script is not running as a Lambda function, then call the lambda_handler function.
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME') == None:
    lambda_handler(None, None)
