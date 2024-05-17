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
################################################################################

import json
import time
import urllib3
from urllib3.util import Retry
import logging
import botocore
import boto3
#
# Create a table of secret names and keys for the username and password for each of the FSxIds.
secretsTable = [
        {"id": "fs-0e8d9172fa545ef3b", "secretName": "mon-fsxn-credentials", "usernameKey": "mon-fsxn-username", "passwordKey": "mon-fsxn-password"},
        {"id": "fs-020de2687bd98ccf7", "secretName": "mon-fsxn-credentials", "usernameKey": "mon-fsxn-username", "passwordKey": "mon-fsxn-password"},
        {"id": "fs-07bcb7ad84ac75e43", "secretName": "mon-fsxn-credentials", "usernameKey": "mon-fsxn-username", "passwordKey": "mon-fsxn-password"},
        {"id": "fs-077b5ff41951c57b2", "secretName": "mon-fsxn-credentials", "usernameKey": "mon-fsxn-username", "passwordKey": "mon-fsxn-password"}
    ]
#
# Set the region where the secrets are stored.
secretsManagerRegion="us-west-2"

################################################################################
# This function is used to obtain the username and password from AWS's Secrets
# Manager for the fsxnId passed in. It returns empty strings if it can't
# find the credentials.
################################################################################
def getCredentials(secretsManagerClient, fsxnId):

    for secretItem in secretsTable:
        if secretItem['id'] == fsxnId:
            secretsInfo = secretsManagerClient.get_secret_value(SecretId=secretItem['secretName'])
            secrets = json.loads(secretsInfo['SecretString'])
            username = secrets[secretItem['usernameKey']]
            password = secrets[secretItem['passwordKey']]
            return (username, password)
    return ("", "")

################################################################################
# This function returns the UUID of the volume that has the ARN passed in. It
# tries a few times, sleeping 1 second between attempts, since the UUID
# doesn't exist until the volume has been created on the ONTAP side.
# It returns an empty string if the ARN is not found.
################################################################################
def getVolumeUUID(fsxClient, volumeId, volumeARN):

    global logger

    cnt = 0
    while cnt < 3:
        awsVolume = fsxClient.describe_volumes(VolumeIds=[volumeId])['Volumes'][0]
        if awsVolume['ResourceARN'] == volumeARN:
            return awsVolume['OntapConfiguration']['UUID']
        logger.debug(f'Looping, getting the UUID {cnt}')
        cnt += 1
        time.sleep(1)

    return ""

################################################################################
################################################################################
def lambda_handler(event, context):

    global logger
    #
    # Set up "logging" to appropriately display messages. It can be set it up
    # to send messages to a syslog server.
    logging.basicConfig(datefmt='%Y-%m-%d_%H:%M:%S', format='%(asctime)s:%(name)s:%(levelname)s:%(message)s', encoding='utf-8')
    logger = logging.getLogger("scan_create_sm_relationships")
#    logger.setLevel(logging.DEBUG)
    logger.setLevel(logging.INFO)
    #
    # Set the logging level higher for these noisy modules to mute thier messages.
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    #
    # Create a Secrets Manager client.
    session = boto3.session.Session()
    secretsManagerClient = session.client(service_name='secretsmanager', region_name=secretsManagerRegion)
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    #
    # Set the https retries to 1.
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)  # pylint: disable=E1123
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Get the FSxN ID, region, volume name, volume ID, and volume ARN from the CloudWatch event.
    fsxId      = event['detail']['responseElements']['volume']['fileSystemId']
    regionName = event['detail']['awsRegion']
    volumeName = event['detail']['requestParameters']['name']
    volumeId   = event['detail']['responseElements']['volume']['volumeId']
    volumeARN  = event['detail']['responseElements']['volume']['resourceARN']
    if fsxId == "" or regionName == "" or volumeId == "" or volumeName == "" or volumeARN == "":
        message = f"Couldn't obtain the fsxId, region, volume name, volume ID or volume ARN from the CloudWatch evevnt."
        logger.critcal(message)
        raise Exception(mmessage)

    logger.debug(f'Data from CloudWatch event: FSxID={fsxId}, Region={regionName}, VolumeName={volumeName}, volumeId={volumeId}.')
    #
    # Get the username and password for the FSxN ID.
    (username, password) = getCredentials(secretsManagerClient, fsxId)
    if username == "" or password == "":
        message = f'No credentials for FSxN ID: {fsxId}.'
        logger.critical(message)
        raise Exception(message)
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
        message = f"Can't find manament IP for FSxN file system with an ID of '{fsxId}'."
        logger.critical(message)
        raise Exception(message)

    volumeUUID = getVolumeUUID(fsxClient, volumeId, volumeARN)
    if volumeUUID == "":
        message = f"Can't find the volumeUUID based on the volume ARN {volumeARN}."
        logger.critical(message)
        raise Exception(message)
    #
    # Set the auto grow feature.
    try:
        endpoint = f'https://{fsxnIp}/api/storage/volumes/{volumeUUID}'
        data = '{"autosize": {"mode": "grow"}}'
        logger.debug(f'Trying {endpoint} with {data}.')
        response = http.request('PATCH', endpoint, headers=headers, timeout=5.0, body=data)
        if response.status >= 200 and response.status <= 299:
            logger.info(f"Updated the auto grow flag for volume name {volumeName}.")
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
    except Exception as err:
        logger.critical(f'Failed to issue API against {fsxnIp}. The error messages received: "{err}".')
