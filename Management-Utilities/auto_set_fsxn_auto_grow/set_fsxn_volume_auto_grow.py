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

################################################################################
# This Lambda function is used to set the auto size feature to 'grow' on a
# volume that was created in an AWS FSx for NetApp ONTAP file system. It is
# expected to be triggered by a CloudWatch event that is generated when a
# volume is created. The function uses the ONTAP API to set the auto size
# mode to 'grow' on the volume therefore it most run within the VPC where the
# FSx for ONTAP file system is located.
#
# Version: %%VERSION%%
# Date: %%DATE%%
################################################################################

import json
import time
import urllib3
from urllib3.util import Retry
import logging
import boto3
import os
#
################################################################################
# Configuration settings.
#
# You can either set the variables in the code below, or set environment variables
# with the same name as the variables below. Except for the secretsTable, you must
# set that in the code if you are not going to use DynamoDb to hold your secrets
# table.
#
# NOTE: The environment variables will take precedence over the variables
# set in the code.
#
################################################################################
#
# Create a table of secret names and keys for the username and password for
# each of the FSxIds. In the example below, it shows using the same
# secret for four different FSxIds, but you can set it up to use
# a different secret and/or keys for the username and password for each
# of the FSxId.
#secretsTable = [
#        {"fsxId": "fs-0e8d9172fa5XXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
#        {"fsxId": "fs-020de2687bdXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
#        {"fsxId": "fs-07bcb7ad84aXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
#        {"fsxId": "fs-077b5ff4195XXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"}
#    ]
#
# If you don't want to define the secretsTable in this script, you can
# define the following variables to use a DynamoDB table to get the
# secret information.
#
# NOTE: If both the secretsTable, and dynamodbSecretsTableName are defined,
# then the secretsTable will be used.
dynamoDbRegion=None
dynamoDbSecretsTableName=None
#
# Set the region where the secrets are stored.
secretsManagerRegion=None
#
# Set the auto size mode. Supported values are "grow", "grow_shrink", and "off".
autoSizeMode = "grow"
#
# Set the grow-threshold-percentage for the volume. This is the percentage of the volume that must be used before it grows.
growThresholdPercentage = 85
#
# Set the maximum grow size for the volume in terms of the percentage of the provisioned size.
maxGrowSizePercentage = 200
#
# Set the shrink-threshold-percentage for the volume. This is the percentage of the volume that must be free before it shrinks.
shrinkThresholdPercentage = 50
#
# Set the minimum shirtk size for the volume in terms of the percentage of the provisioned size.
minShrinkSizePercentage = 100
#
# Set the time to wait for a volume to get created. This Lambda function will
# loop waiting for the volume to be created on the ONTAP side so it can set
# the auto size parameters. It will wait up to the number of seconds specified
# below before giving up. NOTE: You must set the timeout of this function
# to at least the number of seconds specified here, and probably two times
# the number to account for the time it takes to do the API calls,
# otherwise the Lambda timeout feature will kill it before it is able to
# wait as long you want it to. Also note that the main reason for
# it to take a while for a volume to get created is when multiple are being
# created at the same time. So, if you have automation that might create a lot of
# volumes at the same time, you might need to either adjust this number really
# high, or come up with another way to get the auto size mode.
maxWaitTime=60

################################################################################
# This function sets the configuration variables from environment variables if
# they are defined.
################################################################################
def setConfigurationVariables():
    global secretsTable, secretsManagerRegion, autoSizeMode, growThresholdPercentage
    global maxGrowSizePercentage, shrinkThresholdPercentage, minShrinkSizePercentage
    global dynamoDbRegion, dynamoDbSecretsTableName, secretsTable, maxWaitTime, logger

    if os.environ.get('dynamoDbRegion') != None:
        dynamoDbRegion = os.environ['dynamoDbRegion']
    if os.environ.get('dynamoDbSecretsTableName') != None:
        dynamoDbSecretsTableName = os.environ['dynamoDbSecretsTableName']
    if os.environ.get('secretsManagerRegion') != None:
        secretsManagerRegion = os.environ['secretsManagerRegion']
    if os.environ.get('autoSizeMode') != None:
        autoSizeMode = os.environ['autoSizeMode']
    if os.environ.get('growThresholdPercentage') != None:
        growThresholdPercentage = int(os.environ['growThresholdPercentage'])
    if os.environ.get('maxGrowSizePercentage') != None:
        maxGrowSizePercentage = int(os.environ['maxGrowSizePercentage'])
    if os.environ.get('shrinkThresholdPercentage') != None:
        shrinkThresholdPercentage = int(os.environ['shrinkThresholdPercentage'])
    if os.environ.get('minShrinkSizePercentage') != None:
        minShrinkSizePercentage = int(os.environ['minShrinkSizePercentage'])
    if os.environ.get('maxWaitTime') != None:
        maxWaitTime = int(os.environ['maxWaitTime'])
    #
    # Check that all the required variables are set.
    message = ""
    if dynamoDbRegion == None and dynamoDbSecretsTableName == None and 'secretsTable' not in globals():
        message += 'Error, you must either define the secretsTable array at the top of this script, or define dynamodbRegion and dynamoDbSecretsTableName environment variables.\n'

    if secretsManagerRegion == None:
        message += 'Error, you must define the secretsManagerRegion environment variable.\n'

    if autoSizeMode == None or autoSizeMode not in ['grow', 'grow_shrink', 'off']:
        message += 'Error, you must define the autoSizeMode environment variable to either "grow", "grow_shrink", or "off".\n'

    if growThresholdPercentage == None or isinstance(growThresholdPercentage, int) == False or growThresholdPercentage < 0 or growThresholdPercentage > 100:
        message += 'Error, you must define the growThresholdPercentage environment variable between 0 and 100.\n'

    if maxGrowSizePercentage == None or isinstance(maxGrowSizePercentage, int) == False or maxGrowSizePercentage < 0 or maxGrowSizePercentage > 1000:
        message += 'Error, you must define the maxGrowSizePercentage environment variable between 0 and 1000.\n'

    if shrinkThresholdPercentage == None or isinstance(shrinkThresholdPercentage, int) == False or shrinkThresholdPercentage < 0 or shrinkThresholdPercentage > 100:
        message += 'Error, you must define the shrinkThresholdPercentage environment variable between 0 and 100.\n'

    if minShrinkSizePercentage == None or isinstance(minShrinkSizePercentage, int) == False or minShrinkSizePercentage < 0 or minShrinkSizePercentage > 100:
        message += 'Error, you must define the minShrinkSizePercentage environment variable between 0 and 100.\n'

    if maxWaitTime == None or isinstance(maxWaitTime, int) == False or maxWaitTime < 0 or maxWaitTime > 600:
        message += 'Error, you must define the maxWaitTime environment variable between 0 and 600.\n'

    if message != "":
        logger.critical(message)
        raise Exception(message)

################################################################################
# This function is used to obtain the username and password from AWS's Secrets
# Manager for the fsxnId passed in. It returns empty strings if it can't
# find the credentials.
################################################################################
def getCredentials(secretsManagerClient, fsxnId):
    global secretsTable

    for secretItem in secretsTable:
        if secretItem['fsxId'] == fsxnId:
            secretsInfo = secretsManagerClient.get_secret_value(SecretId=secretItem['secretName'])
            secrets = json.loads(secretsInfo['SecretString'])
            username = secrets[secretItem['usernameKey']]
            password = secrets[secretItem['passwordKey']]
            return (username, password)
    return ("", "")

################################################################################
# This function returns the AWS structure for a FSxN volume based on the
# volumeId passed it. It confirms that the volume has been created on the ONTAP
# side by checking that the ResourceARN field equals the volumeARN passed in
# that came from the volume creation event and that the UUID field has been
# populated. It returns None if it can't find the volume.
################################################################################
def getVolumeData(fsxClient, volumeId, volumeARN):

    global logger

    cnt = 0
    while cnt < maxWaitTime:
        awsVolume = fsxClient.describe_volumes(VolumeIds=[volumeId])['Volumes'][0]
        if awsVolume['ResourceARN'] == volumeARN and awsVolume['OntapConfiguration'].get("UUID") != None:
            return awsVolume
        logger.debug(f'Looping, getting the UUID {cnt}')
        cnt += 1
        time.sleep(1)

    return None

################################################################################
################################################################################
def lambda_handler(event, context):

    global logger, secretsTable
    #
    # Set up "logging" to appropriately display messages. It can be set it up
    # to send messages to a syslog server.
    logging.basicConfig(datefmt='%Y-%m-%d_%H:%M:%S', format='%(asctime)s:%(name)s:%(levelname)s:%(message)s', encoding='utf-8')
    logger = logging.getLogger("set_fsxn_volume_auto_size")
#    logger.setLevel(logging.DEBUG)
    logger.setLevel(logging.INFO)
    #
    # Set the logging level higher for these noisy modules to mute thier messages.
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    #
    # Set the configuration variables from environment variables if they are defined.
    setConfigurationVariables()
    #
    # If this is an event from a failed call. Report that and return.
    if event['detail'].get('errorCode') != None:
        logger.warning(f"This is reporting on a error event. Error Code: {event['detail']['errorCode']}. Error Message: {event['detail']['errorMessage']}.")
        return
    #
    # Create a Secrets Manager client.
    session = boto3.session.Session()
    secretsManagerClient = session.client(service_name='secretsmanager', region_name=secretsManagerRegion)
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    #
    # Set the https retries to 1.
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Read in the secretTable if it is not already defined.
    # It is safe to assume dynamoDbRegion and dynamoDbSecretsTableName are defined
    # because the setConfigurationVariables function would have errored out if they
    # were not.
    if 'secretsTable' not in globals():
        dynamodbClient = boto3.resource("dynamodb", region_name=dynamoDbRegion)
        table = dynamodbClient.Table(dynamoDbSecretsTableName)
        response = table.scan()
        secretsTable = response["Items"]
    #
    # Get the FSxN ID, region, volume name, volume ID, and volume ARN from the CloudWatch event.
    fsxId      = event['detail']['responseElements']['volume']['fileSystemId']
    regionName = event['detail']['awsRegion']
    volumeName = event['detail']['requestParameters']['name']
    volumeId   = event['detail']['responseElements']['volume']['volumeId']
    volumeARN  = event['detail']['responseElements']['volume']['resourceARN']
    if fsxId == "" or regionName == "" or volumeId == "" or volumeName == "" or volumeARN == "":
        message = "Couldn't obtain the fsxId, region, volume name, volume ID or volume ARN from the CloudWatch evevnt."
        logger.critical(message)
        return

    logger.debug(f'Data from CloudWatch event: FSxID={fsxId}, Region={regionName}, VolumeName={volumeName}, volumeId={volumeId}.')
    #
    # Get the username and password for the FSxN ID.
    (username, password) = getCredentials(secretsManagerClient, fsxId)
    if username == "" or password == "":
        message = f'No credentials for FSxN ID: {fsxId}.'
        logger.critical(message)
        return
    #
    # Build a header that is used for all the ONTAP API requests.
    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }
    #
    # Get the management IP of the FSxN file system.
    fsxClient = boto3.client('fsx', region_name = regionName)
    fs = fsxClient.describe_file_systems(FileSystemIds = [fsxId])['FileSystems'][0]
    fsxnIp = fs['OntapConfiguration']['Endpoints']['Management']['IpAddresses'][0]
    if fsxnIp == "":
        message = f"Can't find management IP for FSxN file system with an ID of '{fsxId}'."
        logger.critical(message)
        return
    #
    # Get the volume UUID and volume size based on the volume ID.
    volumeData = getVolumeData(fsxClient, volumeId, volumeARN)
    if volumeData == None:
        message=f'Failed to get volume information for volumeID: {volumeId}.'
        logger.critical(message)
        return
    volumeUUID = volumeData["OntapConfiguration"]["UUID"]
    volumeSizeInMegabytes = volumeData["OntapConfiguration"]["SizeInMegabytes"]
    #
    # Set the auto grow feature.
    try:
        endpoint = f'https://{fsxnIp}/api/storage/volumes/{volumeUUID}'
        maximum = volumeSizeInMegabytes * maxGrowSizePercentage / 100 * 1024 * 1024
        minimum = volumeSizeInMegabytes * minShrinkSizePercentage / 100 * 1024 * 1024
        #
        # Make sure the minimum is at least 20MB.
        if minimum < 20 * 1024 * 1024:
            minimum = 20 * 1024 * 1024
        data = json.dumps({"autosize": {"mode": autoSizeMode, "grow_threshold": growThresholdPercentage, "maximum": maximum, "minimum": minimum, "shrink_threshold": shrinkThresholdPercentage}})
        logger.debug(f'Trying {endpoint} with {data}.')
        response = http.request('PATCH', endpoint, headers=headers, timeout=5.0, body=data)
        if response.status >= 200 and response.status <= 299:
            logger.info(f"Updated the auto size parameters for volume name {volumeName}.")
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}. Error message: {response.data}.')
    except Exception as err:
        logger.critical(f'Failed to issue API against {fsxnIp}. The error messages received: "{err}".')
