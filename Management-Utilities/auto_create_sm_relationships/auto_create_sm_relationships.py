#!/bin/python3
#
################################################################################
# This program is used to create SnapMirror relationships for all RW,
# non-clone, non-FlexCache volumes it finds on any FSxN File System that the
# user (or Lambda function) running the program has access to.
#
# It does this by:
#   o Looping on all the regions. Skipping on any that don't support FSx.
#   o Looping on all the FSx file systems. Skipping any non-FSxN file systems.
#   o Obtaining information on all the volumes from the FSxN file system
#     using the ONTAP API.
#   o If a SnapMirror relationship doesn't already exist, and the volume on the
#     AWS side doesn't have a "protect_volume" tag set to "skip", then it
#     creates a SnapMirror relationship using the partner information
#     provided below.
#
# Version: %%VERSION%%
# Date: %%DATE%%
#
################################################################################
#
# The program needs a list of source SVMs to partner associations to know where
# to create the SnapMirror relationships. That information is conveyed via
# the 'partnersTable' variable. The values of each of the fields in the table
# There are three ways to provide the partner information to the program.
# You can either:
#   1) Define an array named "partnersTable" in this script
#   2) Define a DynamoDB table to scan for the information
#   3) Define an S3 bucket and file to fetch the information from.
# 
# If you want to define a variable in the program, then name needs to be
# partnersTable. It should be an array of dictionaries, where each dictionary
# has these fields:
#   fsxId - The AWS ID of the source cluster.
#   svmName - The name of the SVM at the source cluster.
#   partnerFsxId - The AWS ID of the destination cluster.
#   partnerFsxnIp - The IP address of the destination cluster.
#   partnerSvmName - The name of the SVM at the destination cluster.
#   partnerSvmSourceName - The name of the source SVM at the destination cluster.
#
# All of those should be pretty straight forward except for the "partnerSvmSourceName".
# That is the "local name" for the source SVM at the destination cluster. Usually the
# local name is the same as the source SVM name unless the destination cluster
# already has an SVM with the same name. In that case a "local name" has to be
# assigned when you peer the SVMs (a.k.a. vservers) so ONTAP can distinguish them
# apart. To be able to handle that situation the partnerSvmSourceName should
# be set to that local name even if it is the same as the source SVM name.
#
# Here is an example of the partnersTable array:
# partnersTable = [
#        {
#            "fsxId": "fs-04f0ebeXXXXXXXXXX",
#            "svmName": "fsx",
#            "partnerFsxId": "fs-07bcb7aXXXXXXXXXX",
#            "partnerFsxnIp": "198.19.254.83",
#            "partnerSvmName": "fsx",
#            "partnerSvmSourceName": "prod-fsx"
#        },
#        {
#            "fsxId": "fs-04f0ebeXXXXXXXXXX",
#            "svmName": "smb_svm",
#            "partnerFsxId": "fs-07bcb7aXXXXXXXXXX",
#            "partnerFsxnIp": "198.19.254.83",
#            "partnerSvmName": "fsx",
#            "partnerSvmSourceName": "smb_svm"
#        }
#    ]
#
# --------
#
# If you want to use a DynamoDB table, the program expect the following
# attributes for each entry:
# sourceId - Which is the concatenation of the source file system ID
#            followed by a ":" followed by the SVM name. It is done this
#            way because the id has to be unique in the table.
# partnerFsxId - The AWS ID of the destination cluster.
# partnerFsxnIp - The IP address of the destination cluster.
# partnerSvmName - The name of the SVM at the destination cluster.
# partnerSvmSourceName - The name of the source SVM at the destination cluster.
#
# You should set the following variables to instruct the program to use
# the DynamoDB table for the partner information:
# dynamodbRegion="us-west-2"
dynamodbRegion=""
dynamodbPartnersTableName=""
#
# Of course adjust for your region and table name.
#
# --------
#
# If you want to use a file in an S3 bucket, the format of file should be a
# comma separated list of the following fields:
# 
# fsxId,svmName,partnerFsxId,partnerFsxnIp,partnerSvmName,partnerSvmSourceName
#
# Here are the variable to set to get the program to read a file in an S3
# bucket for the partner information.
s3BucketName=""
s3BucketRegion=""
partnersConfigFile=""
#
# Of course adjust for your bucket name, region and file name.
#
# NOTE: If both the DynamoDB table and S3 bucket variables are defined, the
# DynamoDB table will be used and if either are defined, the will be used
# instead of the global variable "partnersTable" defined in this script.
#
################################################################################
#
# The program needs credentials to use to authenticate with the FSxNs with.
# There are three ways you can conveyed this information to the program. You can
# either:
#  1) Define an array named "secretsTable" in this script
#  2) Define a DynamoDB table to scan for the information
#  3) Define an S3 bucket and file to fetch the information from.
#
# If you want to define a variable in the program, then name needs to be
# secretsTable. It should be an array of dictionaries, where each dictionary
# has these fields:
#   fsxId - The AWS ID of the source cluster.
#   secretName - The name of the Amazon SecretsManager secret that holds the username and password keys.
#   usernameKey - The name of the key that holds the username to use.
#   passwordKey - The name of the key that holds the password to use.
#
# Here is an example of the secretsTable array:
# secretsTable = [ 
#        {"fsxId": "fs-04f0ebeXXXXXXXXXX", "secretName": "FSxSecret-Default", "usernameKey": "username", "passwordKey": "password"},
#        {"fsxId": "fs-07bcb7aXXXXXXXXXX", "secretName": "FSxSecret-Default", "usernameKey": "username", "passwordKey": "password"}
#    ]
#
# If you want to use a DynamoDB table, the program expect the following
# attributes for each entry:
#  fsxId - The file system ID
#  SecretName - The name of the Amazon SecretsManager secret that holds the username and password keys.
#  usernameKey - The name of the key that holds the username to use.
#  passwordKey - The name of the key that holds the password to use.
#
# You should set the following variables to instruct the program to use
# the DynamoDB table for the secrets information.
# dynamodbRegion=""   # Should be defined above for the partners information.
dynamodbSecretsTableName=""
#
# ------
#
# If you want to use a file in an S3 bucket, the format of file should be a
# comma separated list of the following fields:
# fsxId,secretName,usernameKey,passwordKey
#
# You'll need to set the following variables to get the program to read a file in an S3
# bucket for the secrets information.
# s3BucketName=""   # Should be defined above for the partners information.
# s3Region=""       # Should be defined above for the partners information.
secretsConfigFile=""
#
# Of course adjust for your bucket name, region and file name.
#
# NOTE: If both the DynamoDB table and S3 bucket variables are defined, the
# DynamoDB table will be used and if either are defined, they will be used
# instead of the global variable "secretsTable" defined in this script.
#
# ------
#
# If you want to limit the regions that are scanned, you can define them here.
# The expected format is a comma separated list of region names.
# If you don't define it then all regions will be scanned.
# regions="us-west-2,us-east-1"
regions=""
#
# If you want to limit the FSxN IDs to look for source volumes from, you
# an define them here. Expected format is a comma separated list of FSxN IDs.
# fsxIds="fs-04f0ebeeXXXXXXXXX,fs-07bcbXXXXXXXXXXXX"
fsxIds=""
# 
# Provide the region the secrets manager resides in:
secretsManagerRegion="us-west-2"
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
# Supported values are: "all", "none", "auto", "snapshot-only".
tieringPolicy="all"
#
# Set to the maximum number of SnapMirror relationships to create during
# a single run.
maxSnapMirrorRelationships=20
#
# Set the following to 'True' (case sensitive) to have the program protect
# all volumes that don't have a "protect_volume" tag set to "skip". Or, set
# it to 'False' to only protect volumes that have a "protect_volume" tag
# set to "protect".
protectAll=True
#
# Set the following to 'True' (case sensitive) to have the program just
# show what it would have done instead of really doing it.
dryRun=False

################################################################################
# !!!!!!!! You shouldn't have to modify anything below here. !!!!!!!!!!!!!!!!!!!
################################################################################

import json
import os
import time
import urllib3
from urllib3.util import Retry
import logging
import botocore
from botocore.config import Config
import boto3
#
################################################################################
# Define a custom exception so we can gracefully exit the program if too many
# snapmirror relationships have been created.
################################################################################
class TooManySMs(Exception):
    """ Custom exception to raise when too many SnapMirror relationships have been created. """

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
def getVolumeProtectTagValue(tags, arn):

    for resource in tags:
        if resource['ResourceARN'] == arn:
            for tag in resource['Tags']:
                if tag['Key'].lower() == "protect_volume":
                    return tag['Value'].lower()

    return("")

################################################################################
# This function returns the ARN of the volume that has the UUID passed in. It
# returns an empty string if the UUID is not found.
################################################################################
def getVolumeARN(awsVolumes, volumeUUID):
    
    global logger

    for awsVolume in awsVolumes:
        if awsVolume.get('OntapConfiguration') is not None and awsVolume['OntapConfiguration'].get('UUID') == volumeUUID:
            return(awsVolume['ResourceARN'])
    logger.warning(f'Failed to get ARN for volume with UUID={volumeUUID}.')
    return("")

################################################################################
# This function is used to obtain the username and password from AWS's Secrets
# Manager for the fsxnId passed in. It returns empty strings if it can't
# find the credentials. It creates a cache of the responses so that it doesn't
# have to call Secrets Manager for the same fsxnId multiple times.
################################################################################
credentialsCache = {}
def getCredentials(fsxnId):

    global secretsManagerClient, secretsTable

    if credentialsCache.get(fsxnId) is not None:
        return (credentialsCache[fsxnId]['username'], credentialsCache[fsxnId]['password'])

    for secretItem in secretsTable:
        if secretItem['fsxId'] == fsxnId:
            secretsInfo = secretsManagerClient.get_secret_value(SecretId=secretItem['secretName'])
            secrets = json.loads(secretsInfo['SecretString'])
            username = secrets[secretItem['usernameKey']]
            password = secrets[secretItem['passwordKey']]
            credentialsCache[fsxnId] = {'username': username, 'password': password}
            return (username, password)
    return ("", "")

################################################################################
# This function returns the partner information for the sources FSxN and
# SVM name passed in.
################################################################################
def getPartnerInfo(fsxId, svmName):

    partnerId = ""
    partnerIp = ""
    partnerSvmName = ""
    partnerSvmSourceName = ""

    for fsx in partnersTable:
        if fsx['fsxId'] == fsxId and fsx['svmName'] == svmName:
            partnerId = fsx['partnerFsxId']
            partnerIp = fsx['partnerFsxnIp']
            partnerSvmName = fsx['partnerSvmName']
            partnerSvmSourceName = fsx['partnerSvmSourceName']
            break

    return (partnerId, partnerIp, partnerSvmName, partnerSvmSourceName)

################################################################################
# The following function will check to see if a SnapMirror relationship already
# exists for the source and destination volumes passed in. It returns True if
# it exists, False otherwise.
#
# It caches the snapmirror relationships for each destination cluster so it
# doesn't have to call the API for each volume.
################################################################################
snapMirrorRelationshipsCache = {}
def checkSnapMirrorRelationshipExists(sourceSVM, sourceVolume, destinationFsId, destinationFsIp, destinationSVM, destinationVolume):

    if snapMirrorRelationshipsCache.get(destinationFsId) is None:
        snapMirrorRelationshipsCache[destinationFsId] = getSnapMirrorRelationships(destinationFsId, destinationFsIp)

    for relationship in snapMirrorRelationshipsCache[destinationFsId]:
        if (relationship['source']['path'] == f'{sourceSVM}:{sourceVolume}' and
            relationship['destination']['path'] == f'{destinationSVM}:{destinationVolume}'):
            return True

    return False

################################################################################
# This function gets all the snapmirror relationships for the fsxnIp passed in.
################################################################################
def getSnapMirrorRelationships(fsxnId, fsxnIp):

    global logger, http

    relationships = []

    try:
        (username, password) = getCredentials(fsxnId)
        if username == "" or password == "":
            logger.error(f'No credentials for FSxN ID: {fsxnId}.')
            return relationships

        auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
        headers = { **auth }

        endpoint = f'https://{fsxnIp}/api/snapmirror/relationships?fields=source,destination'
        logger.debug(f'Trying {endpoint}.')
        response = http.request('GET', endpoint, headers=headers)
        if response.status < 200 or response.status > 299:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
            return relationships
        body = json.loads(response.data.decode('utf-8'))
        relationships += body['records']
        while body.get('next'):
            endpoint = f'https://{fsxnIp}{body["next"]}'
            logger.debug(f'Trying {endpoint}.')
            response = http.request('GET', endpoint, headers=headers)
            if response.status < 200 or response.status > 299:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                return relationships
            body = json.loads(response.data.decode('utf-8'))
            relationships += body['records']
    except Exception as err:
        logger.critical(f'API against {fsxnIp} failed. The error returned: "{err}".')

    return relationships

################################################################################
# This function is used to setup a snapmirror relationship for the source
# volume passed in. It leverages the "create destination endpoint"
# capabilities of the snapmirror API which will create the destination volume
# with the same name as the source volume with a suffix appended to it.
# The suffix is defined above.
################################################################################
def protectVolume(fsxId, svmName, volumeName, partnerId, partnerIp, partnerSvmName, partnerSvmSourceName):

    global logger, http, numSnapMirrorRelationships, dryRun
    #
    # First check to see if the relationship already exists.
    if checkSnapMirrorRelationshipExists(partnerSvmSourceName, volumeName, partnerId, partnerIp, partnerSvmName, f'{volumeName}{config["destinationVolumeSuffix"]}'):
        logger.debug(f'SnapMirror relationship for {fsxId}::{svmName}:{volumeName} to {partnerIp}::{partnerSvmName}:{volumeName}{config["destinationVolumeSuffix"]} already exists.')
        return
    #
    # Create the relationship.
    (username, password) = getCredentials(partnerId)
    if username == "" or password == "":
        logger.error(f'No credentials for FSxN ID: {partnerId}.')
        return
    auth = urllib3.make_headers(basic_auth=f'{username}:{password}')
    headers = { **auth }

    data = {"source": {"path": f"{partnerSvmSourceName}:{volumeName}"},
            "destination": {"path": f"{partnerSvmName}:{volumeName}{config['destinationVolumeSuffix']}"},
            "create_destination": {"enabled" : True, "tiering": {"supported": True, "policy": config['tieringPolicy']}},
            "state": "snapmirrored",
            "policy": config['snapMirrorPolicy']}
    if config['scheduleName'] is not None:
        data["transfer_schedule"] = {"name": config['scheduleName']}

    try:
        if not dryRun:
            endpoint = f'https://{partnerIp}/api/snapmirror/relationships'
            logger.debug(f'Trying {endpoint} with {data}.')
            response = http.request('POST', endpoint, headers=headers, body=json.dumps(data))
            if response.status < 200 or response.status > 299:
                errMessage = "N/A"
                if response.data is not None:
                    errMessage = response.data.decode("utf-8")
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}. Response from the API: {errMessage}')
                return
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} is being SnapMirrored to {partnerId}::{partnerSvmName}:{volumeName}{config["destinationVolumeSuffix"]}.')
            #
            # Now check that it worked.
            body = json.loads(response.data.decode('utf-8'))
            jobId = body['job']['uuid']
            state = "unknown"
            failsafeCounter = 0
            while state != "success" and state != "failure" and failsafeCounter < 60:
                time.sleep(1)
                endpoint = f'https://{partnerIp}/api/cluster/jobs/{jobId}'
                logger.debug(f'Trying {endpoint}.')
                response = http.request('GET', endpoint, headers=headers)
                if response.status < 200 or response.status > 299:
                    logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                    return
                body = json.loads(response.data.decode('utf-8'))
                state = body['state']
                failsafeCounter += 1

            if state == "success":
                logger.info(f'SnapMirror relationship for {fsxId}::{svmName}:{volumeName} to {partnerIp}::{partnerSvmName}:{volumeName}{config["destinationVolumeSuffix"]} was successfully created.')
                numSnapMirrorRelationships += 1 # pylint: disable=E0602
            else:
                if body.get("error") is not None and body["error"].get("message") is not None:
                    errMessage = body["error"]["message"]
                else:
                    errMessage = "N/A"
                logger.error(f'SnapMirror relationship for {fsxId}::{svmName}:{volumeName} to {partnerIp}::{partnerSvmName}:{volumeName}{config["destinationVolumeSuffix"]} failed to be created. Last state was: {state}. Erorr message returned by the API:\n{errMessage}')
        else:
            logger.info(f'Path {fsxId}::{svmName}:{volumeName} would have been SnapMirrored to {partnerId}::{partnerSvmName}:{volumeName}{config["destinationVolumeSuffix"]}.')
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
   
    volumes = []
    try:
        endpoint = f'https://{fsxnIp}/api/storage/volumes?fields=name,svm,type,clone,flexcache_endpoint_type,is_svm_root'
        logger.debug(f'Trying {endpoint}.')
        response = http.request('GET', endpoint, headers=headers, timeout=5.0)
        if response.status == 200:
            data = json.loads(response.data)
            volumes = data['records']
        else:
            logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
            return(volumes)

        while data.get('next'):
            endpoint = f'https://{fsxnIp}{data["next"]}'
            logger.debug(f'Trying {endpoint}.')
            response = http.request('GET', endpoint, headers=headers, timeout=5.0)
            if response.status == 200:
                data = json.loads(response.data)
                volumes += data['records']
            else:
                logger.error(f'API call to {endpoint} failed. HTTP status code: {response.status}.')
                break

    except Exception as err:
        logger.critical(f'Failed to issue API against {fsxnIp}. Cluster could be down. The error messages received: "{err}".')

    return(volumes)

################################################################################
# This function is used to consolidate all the configuration values into a
# single dictionary.
################################################################################
def readinConfig():

    global config, boto3Config, logger, config, secretsTable, partnersTable

    config = {
        "regions": None,
        "fsxIds": None,
        "partnersConfigFile": None,
        "secretsConfigFile": None,
        "secretsManagerRegion": None,
        "s3BucketName": None,
        "s3BucketRegion": None,
        "dynamodbSecretsTableName": None,
        "dynamodbPartnersTableName": None,
        "dynamodbRegion": None,
        "destinationVolumeSuffix": "_dp",
        "snapMirrorPolicy": "MirrorAllSnapshots",
        "scheduleName": None,
        "tieringPolicy": "all",
        "maxSnapMirrorRelationships": 10,
        "protectAll": True
        }
    #
    # Get the values for the variables giving the environment variables the
    # highest priority, then the global variables, and finally the default values.
    for var in config:
        if os.environ.get(var) is not None:
            config[var] = os.environ.get(var)
        elif var in globals() and globals()[var] is not None:
            config[var] = globals()[var]
    #
    # Since the CloudFormation template will set the environment variables
    # to an empty string if someone doesn't provide a value, reset the
    # values back to None.
    for var in config:
        if config[var] == "":
            config[var] = None
    #
    # Convert the logical string to a logic.
    if config.get('protectAll') is not None and type(config['protectAll']) == str and config['protectAll'].lower() == "false": # pylint: disable=E1101
        config['protectAll'] = False
    else:
        config['protectAll'] = True
    #
    # If the s3BucketName is set, then open a client to the s3 service and read
    # in the partners and secrets config files.
    if config['s3BucketName'] is not None:
        #
        # Open a client to the s3 service.
        s3Client = boto3.client('s3', region_name=config['s3BucketRegion'], config=boto3Config)
        if config['partnersConfigFile'] is not None:
            partnersTable = []
            try:
                response = s3Client.get_object(Bucket=config['s3BucketName'], Key=config['partnersConfigFile'])
                partnerContents = response['Body'].read().decode('utf-8')
                for partnerLine in partnerContents.splitlines():
                    if partnerLine.strip() == "":
                        continue
                    if partnerLine.startswith("#"):
                        continue
                    (fsxId, svmName, partnerFsxId, partnerFsxnIp, partnerSvnName, partnerSvmSourceName) = partnerLine.split(",")
                    partnersTable.append({
                            "fsxId": fsxId,
                            "svmName": svmName,
                            "partnerFsxId": partnerFsxId,
                            "partnerFsxnIp": partnerFsxnIp,
                            "partnerSvmName": partnerSvnName,
                            "partnerSvmSourceName": partnerSvmSourceName
                        })
            except Exception as err:
                message = f'Unable to read the partners config file {config["partnersConfigFile"]} from bucket {config["s3BucketName"]}. Error message: "{err}".'
                logger.critical(message)
                raise Exception(message)

        if config['secretsConfigFile'] is not None:
            secretsTable = []
            try:
                response = s3Client.get_object(Bucket=config['s3BucketName'], Key=config['secretsConfigFile'])
                secretsContents = response['Body'].read().decode('utf-8')
                for secretsLine in secretsContents.splitlines():
                    if secretsLine.strip() == "":
                        continue
                    if secretsLine.startswith("#"):
                        continue
                    (fsxId, secretName, usernameKey, passwordKey) = secretsLine.split(",")
                    secretsTable.append({
                            "fsxId": fsxId,
                            "secretName": secretName,
                            "usernameKey": usernameKey,
                            "passwordKey": passwordKey
                        })
            except Exception as err:
                message = f'Unable to read the secrets config file {config["secretsConfigFile"]} from bucket {config["s3BucketName"]}. Error message: "{err}".'
                logger.critical(message)
                raise Exception(message)
        s3Client.close()
    #
    # If the dynamodbRegion is set, then open a client to the dynamodb service and read
    # in the partners and secrets config tables.
    if config['dynamodbRegion'] is not None:
        dynamodbClient = boto3.resource("dynamodb", region_name=config['dynamodbRegion'])

        if config['dynamodbSecretsTableName'] is not None:
            table = dynamodbClient.Table(config['dynamodbSecretsTableName'])
            response = table.scan()
            secretsTable = response["Items"]
        if config['dynamodbPartnersTableName'] is not None:
            table = dynamodbClient.Table(config['dynamodbPartnersTableName'])
            response = table.scan()
            items = response["Items"]
            partnersTable = []
            for item in items:
                partnersTable.append({
                        'fsxId': item['sourceId'].split(":")[0],
                        'svmName': item['sourceId'].split(":")[1],
                        'partnerFsxId': item['partnerFsxId'],
                        'partnerFsxnIp': item['partnerFsxnIp'],
                        'partnerSvmName': item['partnerSvmName'],
                        'partnerSvmSourceName': item['partnerSvmSourceName']
                    })

    if 'partnersTable' not in globals() or len(partnersTable) == 0:
        message = "Error, No partners were have been configured."
        logger.critical(message)
        raise Exception(message)

    if 'secretsTable' not in globals() or len(secretsTable) == 0:
        message = "Error, No secrets were have been configured."
        logger.critical(message)
        raise Exception(message)

################################################################################
# This is the main logic of the program. It loops on all the regions, then all
# the fsx FSxN within each region, checking to see if there are any volumes
# that don't have a snapmirror relationship.
################################################################################
def lambda_handler(event, context):
    #
    # Define some globals so we don't have to pass them around.
    global logger, http, secretsManagerClient, numSnapMirrorRelationships, secretsTable, partnersTable, snapMirrorRelationshipsCache, credentialsCache, boto3Config, config
    #
    # Clear out the caches to prevent them from being re-used for previous Lambda invocations.
    snapMirrorRelationshipsCache = {}
    credentialsCache = {}
    #
    # Configure boto3 to use the more advanced "adaptive" retry method and
    # so we aren't waiting if a region is down, which, at the time of this
    # writing, the Middle East regions are down.
    boto3Config = Config(
        connect_timeout = 2,
        read_timeout = 30,
        retries = {
            'total_max_attempts': 2,
            'mode': 'adaptive'
        },
        s3={'us_east_1_regional_endpoint':'regional'}
    )
    #
    # Set up "logging" to appropriately display messages. It can be set it up
    # to send messages to a syslog server.
    logging.basicConfig(datefmt='%Y-%m-%d_%H:%M:%S', format='%(asctime)s:%(name)s:%(levelname)s:%(message)s', encoding='utf-8')
    logger = logging.getLogger("auto_create_sm_relationships")
    # logger.setLevel(logging.DEBUG)
    logger.setLevel(logging.INFO)
    #
    # Set the logging level higher for these noisy modules to mute thier messages
    # when debugging things.
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    #
    # Read in the configuration from the environment variables, global variables or an s3 bucket.
    readinConfig()
    #
    # Get the list of regions to check. It can be set in the environment
    # variable "regions" or in the global variable "regions". If neither
    # is set, then it will check all regions.
    regionsEnv = config['regions']
    if regionsEnv is not None:
        limitRegions = [item.strip() for item in regionsEnv.split(',')]
    else:
        limitRegions = []
        ec2Client = boto3.client('ec2', config=boto3Config)
        ec2Regions = ec2Client.describe_regions()['Regions']
        for region in ec2Regions:
            limitRegions += [region['RegionName']]
        ec2Client.close()

    if dryRun:
        logger.info('Running in Dry Run mode.')
    #
    # Open a client to the SecretsManager service.
    secretsManagerClient = boto3.client('secretsmanager', region_name=config['secretsManagerRegion'], config=boto3Config)
    #
    # Disable warning about connecting to servers with self-signed SSL certificates.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    #
    # Set the https retries to 1. 
    retries = Retry(total=None, connect=1, read=1, redirect=10, status=0, other=0)  # pylint: disable=E1123
    http = urllib3.PoolManager(cert_reqs='CERT_NONE', retries=retries)
    #
    # Create a counter of the number of SM relationships created.
    numSnapMirrorRelationships = 0
    #
    # Get the list of regions that support fsx.
    fsxRegions = boto3.Session().get_available_regions('fsx')
    #
    # Create an array of the FSxN IDs to scan.
    fsxIdsEnv = config['fsxIds']
    if fsxIdsEnv is not None:
        limitFsxIds = [item.strip() for item in fsxIdsEnv.split(',')]
    else:
        limitFsxIds = []

    try:
        for regionName in limitRegions:
            #
            # Skip regions that don't support fsx.
            if regionName in fsxRegions:
                logger.info(f'Scanning region {regionName}.')
                fsxClient = boto3.client('fsx', region_name=regionName, config=boto3Config)
                tagsClient = boto3.client('resourcegroupstaggingapi', region_name=regionName, config=boto3Config)
                try:
                    #
                    # Create an array of all the AWS FSx file systems.
                    data = fsxClient.describe_file_systems()
                    fsxs = data['FileSystems']
                    nextToken = data.get('NextToken')
                    while nextToken is not None:
                        data = fsxClient.describe_file_systems(NextToken=nextToken)
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
                    # Create an array of all the tags associated with the fsx resource type.
                    data = tagsClient.get_resources(ResourceTypeFilters=['fsx'], ResourcesPerPage=100)
                    tags = data['ResourceTagMappingList']
                    nextToken = data.get('PaginationToken', "")
    
                    while nextToken != "":
                        response = tagsClient.get_resources(ResourceTypeFilters=['fsx'], ResourcesPerPage=100, PaginationToken=nextToken)
                        tags += response['ResourceTagMappingList']
                        nextToken = response.get('PaginationToken', "")
                #
                # Handle the case where one of those AWS API calls fails due to a timeout.
                # Chances are it means the region is down.
                except (botocore.exceptions.ReadTimeoutError, botocore.exceptions.ConnectTimeoutError, botocore.exceptions.ConnectionClosedError) as e:
                    logger.warning(f"boto3 client error while getting the list of FSxNs, volumes or resource tags from region {regionName}. Exception: {e}. Skipping the region.")
                    fsxClient.close()
                    tagsClient.close()
                    continue

                fsxClient.close()
                tagsClient.close()
                #
                # Loop on all the file systems in the region.
                for fsxn in fsxs:
                    #
                    # Skip file systems that are not ONTAP or are not listed in the limitFsxIds array of defined..
                    if fsxn['FileSystemType'] == "ONTAP" and (limitFsxIds == [] or fsxn['FileSystemId'] in limitFsxIds):
                        fsxnId = fsxn['FileSystemId']
                        if (fsxn.get('OntapConfiguration') is not None and
                           fsxn['OntapConfiguration'].get('Endpoints') is not None and
                           fsxn['OntapConfiguration']['Endpoints'].get('Management') is not None and
                           fsxn['OntapConfiguration']['Endpoints']['Management'].get('IpAddresses') is not None):
                            fsxnIp = fsxn['OntapConfiguration']['Endpoints']['Management']['IpAddresses'][0]
                        else:
                            logger.warning(f'No management IP address found for fsxId: {fsxnId}. Probably because it is being created, or deleted.')
                            continue
                        logger.info(f'Getting all the volumes from {fsxnId}.')
                        ontapVolumes = getOntapVolumes(fsxnId, fsxnIp)
                        for ontapVolume in ontapVolumes:
                            #
                            # Only create SnapMirror relationships for RW volumes that arne't clones, vserver_roots or FlexCaches.
                            if (ontapVolume['type'].lower() == "rw" and ontapVolume.get('clone') is not None
                                and not ontapVolume['clone']['is_flexclone'] and ontapVolume.get('flexcache_endpoint_type') != "cache"
                                and ontapVolume.get('is_svm_root') is not True):
                                volumeUUID = ontapVolume['uuid']
                                volumeARN = getVolumeARN(awsVolumes, volumeUUID)
                                if volumeARN != "":
                                    protectTag = getVolumeProtectTagValue(tags, volumeARN)
    
                                    if config['protectAll'] and protectTag != "skip" or not config['protectAll'] and protectTag == "protect":
                                        volumeName = ontapVolume['name']
                                        svmName = ontapVolume['svm']['name']
                                        (partnerId, partnerIp, partnerSvmName, partnerSvmSourceName) = getPartnerInfo(fsxnId, svmName)
                                        if partnerId == "":
                                            logger.warning(f'No partner found for fsxId: {fsxnId} and svmName: {svmName} while trying to protect {volumeName}.')
                                            continue

                                        if getCredentials(partnerId) == ("", ""):
                                            logger.warning(f'No credentials found for partner fsxId: {partnerId} while trying to protect {volumeName}.')
                                            continue
    
                                        protectVolume(fsxnId, svmName, volumeName, partnerId, partnerIp, partnerSvmName, partnerSvmSourceName)
    
                                        if numSnapMirrorRelationships >= config['maxSnapMirrorRelationships']:
                                            raise TooManySMs("Too Many SnapMirror relationships being created.")
    except TooManySMs:
        logger.warning(f'Hit the maximum number of SnapMirorr relationships ({numSnapMirrorRelationships}) created in one run. Exiting.')

    return

if os.environ.get('AWS_LAMBDA_FUNCTION_NAME') == None:
    lambda_handler(None, None)
