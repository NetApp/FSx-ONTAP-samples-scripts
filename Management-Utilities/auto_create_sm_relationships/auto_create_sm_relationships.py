#!/usr/bin/python3
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
# This program is used to create SnapMirror relationships for all RW volumes
# it finds on any FSxN File System that the user running the program has
# access to. It does this by:
#   o Looping on all the regions. Skipping on any that don't support FSx.
#   o Looping on all the FSx file systems. Skipping any non-FSxN file systems.
#   o Obtaining information on all the volumes from the FSxN file system
#     using the ONTAP API. This data includes whether the volumes has an
#     existing SnapMirror relationship. This only is reliable for flexvols and
#     not flexgroups.
#   o If a SnapMirror relationship doesn't already exist, and the volume on the
#     AWS side doesn't have a "protect_volume" tag set to "skip", then it
#     creates a SnapMirror relationship using the partner information
#     provided below.
################################################################################
#
# Create a table of source FSxN IDs and SVMs and its partner (destination)
# cluster and SVM. The "partnerSvmSourceName" is the label for the source SVM at
# the destination cluster. It is usually the same as the SVM name at the source,
# unless there is a name conflict with SVM name at the destination, in which
# case an "alias" is has to be created when you peer the SVMs (a.k.a. vservers).
partnerTable = [
        {
            'fsxId': 'fs-0e8d9172XXXXXXXXX',
            'svmName': 'fsx',
            'partnerFsxnIp': '198.19.253.210',
            'partnerSvmName': 'fsx',
            'partnerSvmSourceName': 'fsx_source'
        },
        {
            'fsxId': 'fs-0e8d9172XXXXXXXXX',
            'svmName': 'fsx_smb',
            'partnerFsxnIp': '198.19.253.210',
            'partnerSvmName': 'fsx',
            'partnerSvmSourceName': 'fsx_smb'
        },
        {
            'fsxId': 'fs-020de268XXXXXXXXX',
            'svmName': 'fsx',
            'partnerFsxnIp': '198.19.255.162',
            'partnerSvmName': 'fsx',
            'partnerSvmSourceName': 'fsx_dest'
        },
    ]
#
# Create a table of secret names and keys for the username and password for each of the FSxIds.
# You can either define an array named "secretsTable", like below or define
# dynamodbTableName, that will specify a DynamoDB table to use. It should have the
# following attributes:
#  id - The file system ID
#  SecretName - The name of the Amazon SecretManger secret that holds the username and password keys.
#  usernameKey - The name of the key that holds the username to use.
#  passwordKey - The name of the key that holds the password to use.
#
#secretsTable = [ 
#        {"id": "fs-0e8d9172XXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "fsxn-username", "passwordKey": "fsxn-password"},
#        {"id": "fs-020de268XXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "fsxn-username", "passwordKey": "fsxn-password"},
#        {"id": "fs-07bcb7adXXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "fsxn-username", "passwordKey": "fsxn-password"},
#        {"id": "fs-077b5ff4XXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "fsxn-username", "passwordKey": "fsxn-password"}
#    ]
#
# NOTE: If both the secretsTable, and dynamodbTableName are defined, the secretsTable will be used.
#
dynamodbTableName="fsxn_secrets"
dynamodbRegion="us-west-2"
#
# Provide the region the secrets manager resides in:
secretsManagerRegion='us-west-2'
#
# Set the suffix string to append to the destination volume.
destinationVolumeSuffix="_dp"
#
# Set the SnapMirror policy to use.
snapMirrorPolicy="MirrorAllSnapshots"
#
# If your policy doesn't have a schedule associated with it, you
# can specify a schedule name here. Set to an empty string otherwise.
scheduleName="hourly"
#
# Set the Tiering policy for the destination volume if it is created.
tieringPolicy="all"
#
# Set to the maximum number of SnapMirror relationships to create during
# a signle run.
maxSnapMirrorRelationships=10
#
# Set the following to 'True' (case sentitive) to have the program just
# show what it would have done and not really peform any actions.
dryRun=True
#
# Set the following to 'True' (case sentitive) to have the program protect
# all volumes that don't have a "protect_volume" tag set to "skip". Or, set
# it to 'False' to only protect volumes that have a "protect_volume" tag
# set to "protect".
protectAll=False

################################################################################
# !!!!!!!! You shouldn't have to modify anything below here. !!!!!!!!!!!!!!!!!!!
################################################################################

import json
import os
import time
import urllib3
from urllib3.util import Retry
import logging
import boto3
#
# Define a custom exception so we can gracefully exit the program if too many
# snapmirror relationships have been created.
class TooManySMs(Exception):

    # Constructor or Initializer
    def __init__(self, value):
        self.value = value

    # __str__ is to print() the value
    def __str__(self):
        return(repr(self.value))


################################################################################
# This function returns the value assigned to the "protect_volume" tag
# associated with the ARN passed in. If none is found, it returns an empty
# string.
################################################################################
def getVolumeProtectTagValue(fsxClient, arn):

    if not arn == "":
        tags = fsxClient.list_tags_for_resource(ResourceARN=arn)
        for tag in tags['Tags']:
            if(tag['Key'].lower() == "protect_volume"):
                return(tag['Value'].lower())
    return("")

################################################################################
# This function returns the ARN of the volume that has the UUID passed in. It
# returns an empty string if the UUID is not found.
################################################################################
def getVolumeARN(awsVolumes, volumeUUID):
    
    global logger

    for awsVolume in awsVolumes:
        if awsVolume['OntapConfiguration']['UUID'] == volumeUUID:
            return(awsVolume['ResourceARN'])
    logger.warning(f'Failed to get ARN for volume with UUID={volumeUUID}.')
    return("")

################################################################################
# This function waits for an ONTAP job to complete.
# NOTE: This function is only needed for creating SM relationships for
# FlexGroup volumes. It returns 'True' if the job completed successfully,
# otherwise it returns False.
################################################################################
def waitForJobToComplete(fsxnIp, headers, jobUUID):

    global logger

    count = 0
    logger.debug(f'Waiting for {jobUUID} to finish.')
    while count < 10:
        try:
            endpoint = f'https://{fsxnIp}/api/cluster/jobs/{jobUUID}'
            logger.debug(f'Trying {endpoint}.')
            response = http.request('GET', endpoint, headers=headers, timeout=5.0)
            if response.status == 200:
                data = json.loads(response.data)
                jobState = data['state'].lower()
                if jobState == "success":
                    return True
                if jobState in ["failure", "error", "quit", "dead", "unknown", "dormant"]:
                    return False
            else:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                return False
        except Exception as err:
            logger.critical(f'Failed to issue API against {fsxnIp}. Endpoint={endpoint}, The error messages received: "{err}".')
            return False
        time.sleep(2)
        count += 1
    logger.error(f'Timed out waiting for a job with a UUID of "{jobUUID}" to complete on {fsxnIp}.')
    return False

################################################################################
# This function is used to obtain the username and password from AWS's Secrets
# Manager for the fsxnId passed in. It returns empty strings if it can't
# find the credentials.
################################################################################
def getCredentials(fsxnId):

    global secretsManagerClient, secretsTable

    for secretItem in secretsTable:
        if secretItem['id'] == fsxnId:
            secretsInfo = secretsManagerClient.get_secret_value(SecretId=secretItem['secretName'])
            secrets = json.loads(secretsInfo['SecretString'])
            username = secrets[secretItem['usernameKey']]
            password = secrets[secretItem['passwordKey']]
            return (username, password)
    return ("", "")

################################################################################
# This function is used to attempt to set up a snapmirror relationship for a
# flexgroup volume. Since I was unable to get the regular API to create
# SnapMirror relationshipsto work, at least when dealing with flexgroups, this
# function does it the old fashioned way of creating a DP volume if it doesn't
# already exist. creating the SM relationship, then initializing it. 
#
# It assumes that the destination SVM exist and has already been peered.
################################################################################
def protectFlexGroup(fsxId, svmName, volumeName):

    global logger, http, numSnapMirrorRelationships

    logger.info(f'Unfortunately, creating snapmirror relationships for FlexGroups has not be thoroughly tested and therefore is disabled.')
    return
    #
    # find the partner fsx cluster, and svmName
    partnerIp = ""
    for fsx in partnerTable:
        if fsx['fsxId'] == fsxId and fsx['svmName'] == svmName:
            partnerIp = fsx['partnerFsxnIp']
            partnerSvmName = fsx['partnerSvmName']
            partnerSvmSourceName = fsx['partnerSvmSourceName']
            break

    if partnerIp == "":
        logger.error(f'No partner found for fsxId: {fsxId} and svmName: {svmName}.')
        return

    (username, password) = getCredentials(fsxId)
    if username == "" or password == "":
        logger.error(f'No credentials for FSxN ID: {fsxId}.')
        return

    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }
    #
    # Check to see if the destination volume already exist.
    try:
        endpoint = f'https://{partnerIp}/api/storage/volumes?name={volumeName}{destinationVolumeSuffix}&svm.name={partnerSvmName}&fields=type,style'
        logger.debug(f'Trying {endpoint}.')
        response = http.request('GET', endpoint, headers=headers, timeout=5.0)
        if response.status == 200:
            data = json.loads(response.data)
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
            return
    except Exception as err:
        logger.critical(f'Failed to issue API against {partnerIp}. Cluster could be down. The error messages received: "{err}".')
        return

    if data['num_records'] < 1:  # If the number of records is 0, then the volume doesn't exist, so try to create it,
        try:
            endpoint = f'https://{partnerIp}/api/storage/volumes'
            data = {
                "name": f'{volumeName}{destinationVolumeSuffix}',
                "svm": partnerSvmName,
                "aggregates": ["aggr1"],
                "style": "flexgroup",
                "type": "dp"
            }
            logger.debug(f'Trying {endpoint} with {data}.')
            if not dryRun:
                response = http.request('POST', endpoint, headers=headers, body=json.dumps(data), timeout=5.0)
                if response.status >= 200 or response.status <= 299:
                    data = json.loads(response.data)
                    jobUUID = data['job']['uuid']
                    if waitForJobToComplete(partnerIp, headers, jobUUID):
                        logger.error(f'Failed to create destination flexgroup volume {partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}.')
                        return
                else:
                    logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                    return
        except Exception as err:
            logger.critical(f'Failed to issue API against {partnerIp}. Cluster could be down. The error messages received: "{err}".')
            return
    else: # The volume already exist. Make sure it is the correct type and style.
        if data['records'][0]['type'].lower() != "dp" or data['records'][0]['style'].lower() != "flexgroup":
            logger.error(f'Destination volume "{partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}" already exist but is not of type "DP", or is not a flexgroup type volume.')
            return
    #
    # At this point we have the destination volume. Time to create the snapmirror relationship.
    try:
        endpoint = f'https://{partnerIp}/api/private/cli/snapmirror'
        data = {
            "source-path": f'{partnerSvmSourceName}:{volumeName}',
            "destination-path": f'{partnerSvmName}:{volumeName}{destinationVolumeSuffix}'
        }
        logger.debug(f'Trying {endpoint} with {data}.')
        if not dryRun:
            response = http.request('POST', endpoint, headers=headers, body=json.dumps(data), timeout=5.0)
            if response.status >= 200 or response.status <= 299:
                data = json.loads(response.data)
                if data['cli_output'][0:len('Operation succeeded:')] != 'Operation succeeded:':
                    logger.error(f'Failed to create the SnapMirror relationship for volume {partnerIp}::{svmName}:{volumeName}. Message={data["cli_output"]}')
                    return
            else:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                return
    except Exception as err:
        logger.critical(f'Failed to issue API against {partnerIp}. Cluster could be down. The error messages received: "{err}".')
        return
    #
    # Last step is to do the initialize.
    try:
        endpoint = f'https://{partnerIp}/api/private/cli/snapmirror/initialize'
        data = {
            "source-path": f'{partnerSvmSourceName}:{volumeName}',
            "destination-path": f'{partnerSvmName}:{volumeName}{destinationVolumeSuffix}'
        }
        logger.debug(f'Trying {endpoint} with {data}.')
        if not dryRun:
            response = http.request('POST', endpoint, headers=headers, body=json.dumps(data), timeout=5.0)
            if response.status < 200 or response.status > 299:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                return
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} is being SnapMirrored to {partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}')
        else:
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} would have been SnapMirrored to {partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}')
        numSnapMirrorRelationships += 1  # pylint: disable=E0602
    except Exception as err:
        logger.critical(f'Failed to issue API against {partnerIp}. Cluster could be down. The error messages received: "{err}".')
        return
    return

################################################################################
# This function is used to setup a snapmirror relationship for the source
# volume passed in. It leverages the "create destionation endpoint"
# capibilities of the snapmirror API which will create the destionation volume
# with the same name as the source volume with a suffix appended to it.
# The suffix is defined above.
#
# NOTE: This program does not check that the Snapmirror relationship is
# successfully created mostly because all the API does is queue up a job
# that should create the relationship.
################################################################################
def protectVolume(fsxId, svmName, volumeName):

    global logger, http, numSnapMirrorRelationships, scheduleName
    #
    # find the partner cluster management IP and svm for the source fsxId and svm.
    partnerIp = ""
    for fsx in partnerTable:
        if fsx['fsxId'] == fsxId and fsx['svmName'] == svmName:
            partnerIp = fsx['partnerFsxnIp']
            partnerSvmName = fsx['partnerSvmName']
            partnerSvmSourceName = fsx['partnerSvmSourceName']
            break

    if partnerIp == "":
        logger.error(f'No partner found for fsxId: {fsxId} and svmName: {svmName}.')
        return

    (username, password) = getCredentials(fsxId)
    if username == "" or password == "":
        logger.error(f'No credentials for FSxN ID: {fsxId}.')
        return

    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }

    try:
        endpoint = f'https://{partnerIp}/api/snapmirror/relationships/'
        data = {"source": {"path": f"{partnerSvmSourceName}:{volumeName}"},
                "destination": {"path": f"{partnerSvmName}:{volumeName}{destinationVolumeSuffix}"},
                "create_destination": {"enabled" : True, "tiering": {"supported": True, "policy": tieringPolicy}},
                "state": "snapmirrored",
                "policy": snapMirrorPolicy}
        #
        # To be safe, check that the variable exist, since it migth have been
        # commented out above.
        try:
            nop = scheduleName
        except NameError:
            scheduleName = ""

        if scheduleName != "":
            data["transfer_schedule"] = {"name": scheduleName}

        logger.debug(f'Trying {endpoint} with {data}.')
        if not dryRun:
            response = http.request('POST', endpoint, headers=headers, body=json.dumps(data))
            if response.status < 200 or response.status > 299:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                return
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} is being SnapMirrored to {partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}.')
        else:
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} would have been SnapMirrored to {partnerIp}::{partnerSvmName}:{volumeName}{destinationVolumeSuffix}.')
        numSnapMirrorRelationships += 1
    except Exception as err:
        logger.critical(f'API against {partnerIp} failed. Volume not protected. The error returned: "{err}".')
        return

################################################################################
# This function is used to return all the volumes that are in the FSxN cluster.
# It returns an empty list if there are no volumes or if there was an error.
################################################################################
def getOntapVolumes(fsxId, fsxnIp):

    global logger, http

    (username, password) = getCredentials(fsxId)
    if username == "" or password == "":
        logger.error(f'No credentials for FSxN ID: {fsxId}.')
        return([])
    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }
    
    try:
        endpoint = f'https://{fsxnIp}/api/storage/volumes?fields=*'
        logger.debug(f'Trying {endpoint}.')
        response = http.request('GET', endpoint, headers=headers, timeout=5.0)
        if response.status == 200:
            data = json.loads(response.data)
            return(data['records'])
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
    except Exception as err:
        logger.critical(f'Failed to issue API against {fsxnIp}. Cluster could be down. The error messages received: "{err}".')

    return([])

################################################################################
# This is the main logic of the program. It loops on all the regions, then all
# the fsx volumes within each region, checking to see if there are any volumes
# that don't have a snapmirror relationship.
#
# NOTE: It depends on the "snapmiror.destination.ontap" field from the source
# ontap volume structure to determine of a SM relationship already exist.
# Turns out that field is not maintained for FlexGroup volumes.
################################################################################
def lambda_handler(event, context):
    #
    # Define some globals so we don't have to pass them around.
    global logger, http, secretsManagerClient, numSnapMirrorRelationships, secretsTable
    #
    # Get a list of all the regions.
    ec2Client = boto3.client('ec2')
    regions = ec2Client.describe_regions()
    #
    # Set up "logging" to appropriately display messages. It can be set it up
    # to send messages to a syslog server.
    logging.basicConfig(datefmt='%Y-%m-%d_%H:%M:%S', format='%(asctime)s:%(name)s:%(levelname)s:%(message)s', encoding='utf-8')
    logger = logging.getLogger("auto_create_sm_relationships")
#    logger.setLevel(logging.DEBUG)
    logger.setLevel(logging.INFO)
    #
    # Ensure the logging level on higher for these noisy modules to mute thier messages.
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    #
    if dryRun:
        logger.info('Running in Dry Run mode.')
    #
    # Create a Secrets Manager client.
    session = boto3.session.Session()
    secretsManagerClient = session.client(service_name='secretsmanager', region_name=secretsManagerRegion)
    #
    # Read in the secretTable
    if 'secretsTable' not in globals():
        if 'dynamodbRegion' not in globals() or 'dynamodbTableName' not in globals():
            raise Exception('Error, you must either define the secretsTable array, or define dynamodbRegion and dynamodbTableName')

        dynamodbClient = boto3.resource("dynamodb", region_name=dynamodbRegion)
        table = dynamodbClient.Table(dynamodbTableName)

        response = table.scan()
        secretsTable = response["Items"]
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    #
    # Set the https retries to 1. 
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)  # pylint: disable=E1123
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Create a counter of the number of SM reltionships created.
    numSnapMirrorRelationships = 0
    #
    # Get the list of regions that support fsx.
    fsxRegions = boto3.Session().get_available_regions('fsx')

    try:
        for region in regions['Regions']:
            regionName=region['RegionName']
            #
            # Skip regions that don't support fsx.
            if regionName in fsxRegions:
                logger.debug(f'Scanning region {regionName}.')
                fsxClient = boto3.client('fsx', region_name=regionName)
                #
                # Create an array of all the AWS FSx file systems.
                data = fsxClient.describe_file_systems()
                fsxs = data['FileSystems']
                nextToken = data.get('NextToken')
                while nextToken is not None:
                    data = fsxClient.describe_file_systems()
                    fsxs += data['FileSystems']
                    nextToken = data.get('NextToken')
                #
                # Create an array of all the AWS volumes.
                data = fsxClient.describe_volumes()
                awsVolumes = data['Volumes']
                nextToken = data.get('NextToken')
                while nextToken is not None:
                    data = fsxClient.describe_volumes(NextToken=nextToken)
                    awsVolumes += data['Volumes']
                    nextToken = data.get('NextToken')
                #
                # Loop on all the file systems in the region.
                for fsxn in fsxs:
                    #
                    # Skip file systems that are not ONTAP.
                    if fsxn['FileSystemType'] == "ONTAP":
                        fsxnId = fsxn['FileSystemId']
                        fsxnIp = fsxn['OntapConfiguration']['Endpoints']['Management']['IpAddresses'][0]
                        logger.debug(f'Scanning fsxn with IP {fsxnIp}.')
                        ontapVolumes = getOntapVolumes(fsxnId, fsxnIp)  # Get all the volumes in the file system.
                        for ontapVolume in ontapVolumes:
                            if ontapVolume['type'].lower() == "rw" and not ontapVolume['snapmirror']['destinations']['is_ontap']:
                                volumeUUID = ontapVolume['uuid']
                                volumeARN = getVolumeARN(awsVolumes, volumeUUID)
                                protectTag = getVolumeProtectTagValue(fsxClient, volumeARN)

                                if protectAll and protectTag != "skip" or not protectAll and protectTag == "protect":
                                    volumeName = ontapVolume['name']
                                    svmName = ontapVolume['svm']['name']
                                    if ontapVolume['style'] == "flexgroup":
                                        protectFlexGroup(fsxnId, svmName, volumeName)
                                    else:
                                        protectVolume(fsxnId, svmName, volumeName)
                                    if numSnapMirrorRelationships >= maxSnapMirrorRelationships:
                                        raise TooManySMs("Too Many SnapMirror relationships being created.")

    except TooManySMs:
        logger.warning(f'Hit the maximum number of SnapMirorr relationships ({numSnapMirrorRelationships}) created in one run. Exiting.')

    return

if os.environ.get('AWS_LAMBDA_FUNCTION_NAME') == None:
    lambda_handler(None, None)
