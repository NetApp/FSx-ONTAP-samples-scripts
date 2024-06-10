# Automatically create SnapMirror relationships for FSxN file systems

## Introduction
This script is used to ensure that all your volumes, in all your FSxN file systems, are SnapMirror'ed to a remote FSxN file system. It does this by:

- Looping on all the AWS regions that support FSx.
- For each region, it loops on all the FSxN file systems.
- For each FSxN file system, it obtains the list of the volumes it has using the ONTAP API.
- For each of the volumes it checks if the "snapmirror.destinations.is_ontap" field is set to false. Meaning it doesn't have an existing SnapMirror relationship.
- If it is set to false, then it checks from the AWS side to see if there is a "protect_volume" tag set to "skip".
- If there isn't one, then it uses the ONTAP SnapMirror API to create the SnapMirror relationship. This API will create a destination volume if it does not already exist.

**NOTE:** This script only creates SnapMirror relationships for FlexVol volumes. It does not create SnapMirror relationships for FlexGroup volumes.

## Set Up
There are a few things you need to do in order to get this script to run properly:

- Set up a secret for each of the FSxN file systems in the AWS Secrets Manager. Each secret should have two "keys" (they can be named anything, since you set the key name in the script):
    - username - set to the username you want the script to use when issuing API to the ONTAP system.
    - password - set to the password of the username specified with the username key.
- Edit the top of the script and fill in a few variables:
- partnerTable - This table provides the association with a source FSxN file system to its partner cluster (i.e. where its volumes should be SnapMirror'ed to.) There should be five fields for each entry:
    - fsxId - Set to the AWS ID of the FSx file system.
    - svmName - Set to the SVM name on the FSxN file system.
    - partnerFsxnIP - Set to the IP address of the management port of the partner FSxN file system.
    - partnerSvmName - The name of the SVM where you want the SnapMirror destination volume to resided.
    - partnerSvmSourceName - Is the "peered name" of the source SVM. Usually, it is the same as the source SVM, but can be different if that same name already exists on the partner file system. When you peer the SVM it will require you to create an alias for the source SVM so all the SVM names are unique.
- secretsTable - This table provides the secret name, and username and password keys to use for each of the file systems. It should have 4 fields:
    - id - Set to the AWS File System ID
    - secretName - Set to the name of the secret created in step one.
    - usernameKey - Set to the name of the key that holds the username. In the instructions above, it should be set to 'username' but this allows you to use any key name you want.
    - passwordKey - Set to the name of the key that holds the password.
*NOTE:* Instead of defining the secretsTable in the script, you can define dynamodbTableName and dynamodbRegion and the script will read the secretsTable from the DynamoDB table. The table should have the same fields as the secretsTable.
- secretsManagerRegion - Set to the region where the Secrets Manager has been set up.
- destinationVolumeSuffix - Set to the string you want appended to the source volume name to create the destination volume name.
- snapMirrorPolicy - Set to the Data ONTAP SnapMirror policy you want the assigned to the SnapMirror relationship.
- maxSnapMirrorRelationships - Set to the maximum number of SnapMirror relationship initializations you want to allow running at the same time.
- dryRun - If set to 'True' (case sensitive) the program will just show that it would have done, instead of actually creating the SnapMirror relationships.

If you want to run this script as a Lambda program, then you'll need to
- Create a role that has the following permissions:
    - secretsmanager:GetSecretValue
    - ec2:DescribeRegions
    - fsx:DescribeFileSystems
    - fsx:DescribeVolumes
    - fsx:ListTagsForResources
    - dynamodb:GetItem - Optionally, if you are using a DynamoDB table to store the secretsTable.

Create AWS endpoints for any services that it uses. Currently that is:
- ec2
- fsx
- SecretsManager
- dynamodb - Optionally, if you are using a DynamoDB table to store the secretsTable.

# Running The Script
To run the script on a Linux host, you just need to change the UNIX permissions on the file to be executable, then run it as a command:

chmod +x auto_creaate_sm_relationships
 
./auto_create_sm_relationships

To run it as a Lambda function you will need to:
- Create the Lambda function with a Python runtime, from scratch, and paste the program into code box and save it.
- Associate the role created above with the Lambda function.
- Create the AWS service endpoints mentioned above.
- Adjust the default timeout from 4 seconds to at least 20, maybe 60 seconds.
- Once you have tested that it run successfully, creating an eventBridge that will trigger it to run on a regular basis (e.g. once or twice a day).
