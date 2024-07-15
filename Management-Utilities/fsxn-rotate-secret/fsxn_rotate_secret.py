################################################################################
# This program is used to rotate a AWS secret manager secret, and update the
# corresponding FSxN file system with the new secret. It depends on the
# secret having the following tags associted with the secret:
#   fsxId: The ID of the FSx file system to update.
#   region: The region in which the FSx file system is located.
################################################################################

import boto3
import logging

charactersToExcludeInPassword = '/"\'\\'

################################################################################
# THis function is used to get the value of a tag from a list of tags.
################################################################################
def getTagValue(tags, key):
    for tag in tags:
        if tag['Key'] == key:
            return tag['Value']
    return None

################################################################################
# This function is used to create a new version of a Secret Manager secret
# asscoiated with the supplied token. It will first check to see if a secret
# already exists, and if not, it will create a new secret with version stage
# set to AWSPENDING.
################################################################################
def create_secret(secretsClient, arn, token):
    global logger
    #
    # Make sure the current secret exists
    secretsClient.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
    #
    # Now try to get the secret version, if that fails, put a new secret
    try:
        secretsClient.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info(f"create_secret: Secret already exist secret for ARN {arn} with VersionId {token}.")
    except secretsClient.exceptions.ResourceNotFoundException:
        #
        # Generate a random password.
        passwd = secretsClient.get_random_password(ExcludeCharacters=charactersToExcludeInPassword, PasswordLength=8, IncludeSpace=False)
        #
        # Put the secret.
        secretsClient.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString=passwd['RandomPassword'], VersionStages=['AWSPENDING'])
        logger.info(f"create_secret: Successfully put secret for ARN {arn} with ClientRequestToken {token} and VersionStage = 'AWSPENDING'.")

################################################################################
# This functino is used to set the password of an FSxN file system based
# on a secret stored in the Secrets Manager pointed to by the supplied secret
# ARN with VersionId equal to token and VersionStage equal to AWSPENDING.
################################################################################
def set_secret(secretsClient, arn, token):
    global logger

    try:
        secretValueResponse = secretsClient.get_secret_value(SecretId=arn, VersionStage="AWSPENDING", VersionId=token)
    except ClientError as e:
        logger.error(f"Unable to retrieve secret for {arn} in VersionStage = 'AWSPENDING'. Error={e}")
        #
        # Pass the exception on so the Secret Manager will know that the rotate failed.
        raise Exception(e)

    password = secretValueResponse['SecretString']
    #
    # Get the FSx file system ID and region from the secret's tags.
    secretMetadata = secretsClient.describe_secret(SecretId=arn)
    tags = secretMetadata['Tags']
    fsxId = getTagValue(tags, 'fsxId')
    fsxRegion = getTagValue(tags, 'region')
    if fsxId is None or fsxRegion is None:
        message=f"Unable to retrieve the FSx file system ID ('fsxId') or region ('region') tags from secret {arn}."
        logger.error(message)
        raise Exception(message)   # Signal to the Secrets Manager that the rotation failed.
    #
    # Update the FSx file system with the new password.
    fsxClient = boto3.client(service_name='fsx', region_name=fsxRegion)
    fsxClient.update_file_system(OntapConfiguration={"FsxAdminPassword": password}, FileSystemId=fsxId)
    logger.info(f"Successfully set the FSxN ({fsxId}) password to secret stored in {arn} with a VersionStage = 'AWSPENDING'.")

################################################################################
# Usually this function would be used to test that the service has been updated
# to use the new password. However, since the FSx file system is not accessible
# from this Lambda function, unless it is running within the FSxN's VPC, there
# is no way to test that the password has been set correctly.
################################################################################
def test_secret(secretsClient, arn, token):
    global logger
    return

################################################################################
# This function is used to finalize the secret rotation process. it does this
# by marking the secret version passed in as the AWSCURRENT secret.
################################################################################
def finish_secret(secretsClient, arn, token):
    global logger
    #
    # First get the current version.
    metadata = secretsClient.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == token:
                #
                # The new version is already marked as current.
                logger.info(f"finishSecret: Version {version} already marked as AWSCURRENT for {arn}")
                return
            current_version = version
            break
    #
    # Finalize by staging the secret version current
    secretsClient.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token, RemoveFromVersionId=current_version)
    logger.info(f"finishSecret: Successfully set AWSCURRENT stage to version {token} for secret {arn}.")


################################################################################
# This is the main entry point for the Lambda function. It expects the following
# parameters:
#   event['SecretId']: The ARN of the secret to rotate.
#   event['ClientRequestToken']: The ClientRequestToken associated with the secret version.
#   event['Step']: The rotation step (createSecret, setSecret, testSecret, or finishSecret).
#
################################################################################
def lambda_handler(event, context):
    global logger

    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    #
    # Set the logging level higher for these noisy modules to mute thier messages.
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("botocore").setLevel(logging.WARNING)
    
    logger.info(f'arn={arn}, token={token}, step={step}.')
    #
    # Create a client to the secrets manager service.
    secretsClient = boto3.client('secretsmanager')
    #
    # Make sure the version is staged correctly.
    metadata = secretsClient.describe_secret(SecretId=arn)
    if not metadata['RotationEnabled']:
        message = f"Secret {arn} is not enabled for rotation."
        logger.error(message)
        raise Exception(message)
    #
    # If rotation is enabled, then a version is created with a version-id
    # equal to the token.
    versions = metadata['VersionIdsToStages']
    if token not in versions:
        message = f"Secret version {token} has no stage for rotation of secret {arn}."
        logger.error(message)
        raise Exception(message)
    #
    # Now check that the version hasn't already been promoted to AWSCURRENT and if not
    # that a AWSPENDING staging exist.
    if "AWSCURRENT" in versions[token]:
        logger.info(f"Secret version {token} already set as AWSCURRENT for secret {arn}.")
        return
    elif "AWSPENDING" not in versions[token]:
        message = f"Secret version {token} not set as AWSPENDING for rotation of secret {arn}."
        logger.error(message)
        raise Exception(message)
    #
    # At this point we are ready to process the request.
    if step == "createSecret":
        create_secret(secretsClient, arn, token)

    elif step == "setSecret":
        set_secret(secretsClient, arn, token)

    elif step == "testSecret":
        test_secret(secretsClient, arn, token)

    elif step == "finishSecret":
        finish_secret(secretsClient, arn, token)

    else:
        raise ValueError(f"Invalid step parameter '{step}'.")
