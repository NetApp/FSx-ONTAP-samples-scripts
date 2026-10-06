# Automatically create SnapMirror relationships for FSxN file systems

## Introduction
This program is used to ensure that all the volumes, in all of your FSxN file systems,
are SnapMirror'ed to a remote FSxN file system. It does this by:

- Looping on all the AWS regions that support FSx.
- For each region, it loops on all the FSxN file systems.
- For each FSxN file system, obtain the list of the volumes it has.
- For each  volumes it checks to see if it is:
    - A RW type volume
    - Not a clone volume
    - Not a FlexCache volume
    - Not a vserver root volume
    - Not already in an existing SnapMirror relationship to the specified destination
    - Doesn't have an AWS tag with a key of `protect_volume` with a value of `skip`.
- If it passes all those checks then it uses the ONTAP SnapMirror API to create the SnapMirror relationship.

**NOTES**
- The ONTAP API creates the destination volume and will error out if the destination volume already exists.
- The program assumes that the cluster and vservers have already been peered.

## Prerequisites
There are a couple of things you need to do in order to get this script to run properly:

1. Set up an AWS SecretsManager secret for each of the FSxN file systems, both sources and destinations,
that the program is going to work with. Each secret should have two "keys" (they can be named anything, since you set the
name of the key in the `secretsTable` defined below):

    |Key|Description|
    |-|-|
    |username | Set to the username you want the script to use.|
    |password | Set to the password of the username.|

1. If you are planning on deploying as a Lambda function, or just want an easier way of maintaining the
associations of the source and destination SVMs and the file system to Secrets Manager secrets then you can
either create CSV (Comma Separated Values) files with the information and store them in an S3 bucket or
you can put the information into a DynamoDB table. The specific formats of the file and tables are listed
in the [Appendix](#appendix) section below.

## Deployment Options

There are two way to deploy the program:

- As a Lambda function.
- As a standalone program running on a system that has Python installed

### Deploying as a Lambda function
Note that since Lambda function has to communicate with the FSxN file systems it has to run
with a subnet of a VPC. Because of that it is requirement to pick a subnet that has network
connectivity to all the file systems, as well as the AWS service endpoints. Since accessing
AWS service endpoints can be problematic if the Lambda function is deployed
in a "Public subnet" (i.e. one with an Internet Gateway in it) it is highly recommended to
deploy it in private subnet that has access to the Internet, typically via a NAT gateway.

To make it easy to deploy the program as a Lambda function a CloudFormation template has
been created. To use it just download the template file [found here](cloudformation.yaml)
and create a CloudFormation stack from the AWS console.

Once you have loaded the file, it will prompt you for the following items:

|Parameter|Required|Purpose|
|--------|--------|------|
|Stack Name| Yes | Provides a unique name for the stack. Note that this value is used as a suffix to a lot of the resources so it is recommended to keep to short.|
|Subnet IDs| Yes | The subnets that the Lambda function run from. It is recommended to select at least two. They must have connectivity to the FSxNs and be in private subnets (i.e. subnets without an Internet Gateway attached).|
|Security Group IDs | Yes | The AWS Security Group IDs to assign to the Lambda function. The only requirement is for outbound TCP port 443 to the FSxNs  and to the AWS endpoints.|
|Check Interval | Yes | The number of hours between checks for new volumes to protect.|
|Secrets ARN pattern | No | An ARN pattern that will match all the secrets that the program will get values from to obtain the credentials for the FSxN file systems. This value is ignored if a role ARN is provided below.|
|Secrets Manager Region | Yes | This specifies the AWS region where all the secrets reside.|
|Role ARN | No | An ARN to a role to assign to the Lambda function. See the [Required Permissions](#required-permissions) section in the appendix for the required permissions.|
|Create Watchdog Alarm | No | If set to True a CloudWatch alarm will be created that will alert you if the Lambda function fails for any reason.|
|SNS Topic ARN | No | The ARN to an SNS topic that the CloudWatch Alarm will send alerts to.|
|Max Run Time | Yes | The maximum number of seconds to allow the program to run. Recommended to be at least 90 seconds if you want it to scan all regions. Must to be less than 900 (15 minutes).|
|Regions | No | Provide a comma separated list of regions to scan for FSxN file systems. If left blank it will scan all AWS regions.|
|FSx IDs | No | Provide a comma separated list of FSxN file systems for the program to protect. If left blank will attempt to protect all FSxNs in the regions that it is allowed to scan.|
|Destination Volume Suffix | No | The string to append to the volume name at the destination file system. Can be left blank to keep the names the same.|
|SnapMirror Policy | Yes | The SnapMirror Policy to assign to the SnapMirror relationship.|
|Schedule Name | No | The name of the update schedule to assign to the SnapMirror relationship.|
|Tiering Policy | Yes | The tiering policy to assign to the destination volume.|
|Maximum SnapMirror Relationships | Yes | The maximum number of SnapMirror relationships you want to allow the program to create on any give invocation. This is a safe guard to ensure it doesn't create too many at a time. To disable the safe guard, just set to a high number.|
|Protect All | Yes | Allows you to change the default behavior of creating SnapMirror relationships. If this parameter is set to `True` it will create SnapMirror relationships for all volumes that don't have a `protect_volume` tag set to `skip`. If set to `False` it will only creating SnapMirror relationships for volumes that have a `protect_volume` tag set to `protect`.|
|S3 Bucket Name | No | The S3 bucket that contains the files that have the list of secrets ARNs and svm to svm relationships.|
|S3 Bucket Region | No | The region where the S3 bucket resides.|
|Partners File | No | The file within the S3 bucket that contains the SVM to SVM relationship information. The format of this file is specified in the [S3 Bucket File formats](#s3-bucket-file-formats) section below.|
|Secrets File | No | The file within the S3 bucket that contains the secrets to file system associations. The format of this file is specified in the [S3 Bucket File formats](#s3-bucket-file-formats) section below.|
|DynamoDB Region | No | The region of the DynamoDB that contains the partners and secret tables. |
|Partners Table | No | The DynamoDB table that contains the SVM to SVM relationship information. The format of this table is specified in the [DynamoDB Table Structures](#dynamodb-table-structures) section below.|
|Secrets Table | No | The DynamoDB table that contains the secrets to file system associations. The format of this table is specified in the [DynamoDB Table Structures](#dynamodb-table-structures) section below.|

Once you have filled in the values click on the `Next` button. From that page, just scroll to the bottom and click on the check box next to
the disclaimer acknowledging that the template might create a role. If you have provided a role ARN it will not create a role. Next, click
on the `Next` button. This last page just summarizes all the selections that have been made. Scroll to the bottom and click on the `Submit` button.

Within a few minutes it should deploy the solution. Once it is done, click on the `Resources` tab and click on the Lambda function URL. That
should bring you to the Lambda function within the AWS console. On that page click on the `Test` tab and click on the `Test` button. This forces the program to run.
Once it is done it will display the output that came from the program, including any error messages. If there are error messages
try to resolve them. If you can't open an issue on this GitHub repository and someone will help you.

### Deploying as a standalone program

To use this program in a standalone program you'll need to ensure Python (version 3.12 or higher) is installed as
well as the 'boto3' Python package. Boto3 is the AWS SDK that allows the program to issue AWS APIs. The program
will need some AWS permissions to run. The list of them are in the [Required Permissions](#required-permissions) section below. You can either create a role with at least
these permissions and assign it to the EC2 instance that is used to run the program. Or, if not running from an
EC2 instance, download and install the aws cli and configure it with a access key and secret key. While a session
key would work, it would not be practical to have to update it everyday.

Once you have given the program the permissions it needs you'll need to configure it. There are two ways to do so,
either by editing the top of the script itself, or by creating environment variables with the same name as the 
global variables. The one exception to the global variable option is for the partners and secrets tables. For those
you'll need to either create a Python dictionary within the script that contains the information, or create a partners and secrets file
and put them into an S3 bucket. The format of the files are listed [Appendix](#appendix) below. Another option is to create tables
in a DynamoDB that contains the information. The structure of those tables are also listed in the [Appendix](#appendix) below.

Here are the list of variable that you can set:

|Parameter|Required|Purpose|
|--------|--------|------|
|s3BucketName | No | The S3 bucket that contains the files that have the list of secrets and svm to svm relationships.|
|s3BucketRegion | No | The region where the S3 bucket resides.|
|partnersConfigFile | No | The file within the S3 bucket that contains the SVM to SVM relationship information. The format of this file is specified in the [S3 Bucket File formats](#s3-bucket-file-formats) section below.|
|secretsConfigFile | No | The file within the S3 bucket that contains the secrets to file system associations. The format of this file is specified in the [S3 Bucket File formats](#s3-bucket-file-formats) section below.|
|dynamodbRegion | No | The region of the DynamoDB that contains the partners and secret tables. |
|dynamodbPartnersTableName | No | The DynamoDB table that contains the SVM to SVM relationship information. The format of this table is specified in the [DynamoDB Table Structures](#dynamodb-table-structures) section below.|
|dynamodbSecretsTableName | No | The DynamoDB table that contains the secrets to file system associations. The format of this table is specified in the [DynamoDB Table Structures](#dynamodb-table-structures) section below.|
|secretsManagerRegion | Yes | This specifies the AWS region where all the secrets reside.|
|regions | No | Provide a comma separated list of regions to scan for FSxN file systems. If left blank it will scan all AWS regions.|
|FsxIds | No | Provide a comma separated list of FSxN file systems for the program to protect. If left blank will attempt to protect all FSxNs in the regions that it is allowed to scan.|
|destinationVolumeSuffix | No | The string to append to the volume name at the destination file system. Can be left blank to keep the names the same.|
|snapMirrorPolicy | Yes | The SnapMirror Policy to assign to the SnapMirror relationship.|
|scheduleName | No | The name of the update schedule to assign to the SnapMirror relationship.|
|tieringPolicy | Yes | The tieting policy to assign to the destination volume.|
|maxSnapMirrorRelationships | Yes | The maximum number of SnapMirror relationships you want to allow the program to create on any give invocation. This is a safe guard to ensure it doesn't create too many at a time. To disable, just set it to a high number.|
|protectAll | Yes | Allows you to change the default behavior of creating SnapMirror relationships. If this parameter is set to `True` it will create SnapMirror relationships for all volumes that don't have a `protect_volume` tag set to `skip`. If set to `False` it will only creating SnapMirror relationships for volumes that have a `protect_volume` tag set to `protect`.|
|dryRun | No | If set to True it will not create any SnapMirror relationships, but instead just output a message saying what it would have done. Note this variable can only be set within the program, not via an environment variable.|

Once you have filled in the variables you can run the script by just passing it as an argument to the python program:
```
python3 auto_create_sm_relationships.py
```

## Appendix

### DynamoDB Table Structures
#### Partners Table
This table provides the association with a source FSxN file system to its partner cluster (i.e. where its volumes should be SnapMirror'ed to.) There should be five fields for each entry:
- soureceId - Which is the concatenation of the source file system ID followed by a ":" followed by the SVM name. It is done this way because the id has to be unique in the table. It is split up into its two components in the script when it is read in.
- partnerFsxnId - Set to the AWS ID the partner FSxN file system.
- partnerFsxnIp - Set to the IP address of the management port of the partner FSxN file system.
- partnerSvmName - The name of the SVM where you want the SnapMirror destination volume to reside.
- partnerSvmSourceName - Is the "local name" of the source SVM. Usually, it is the same as the source SVM, but can be different if that same name already exists on the partner file system. When you peer the SVM it will require you to create an alias for the source SVM so all the SVM names are unique.

#### Secrets Table
This table provides the secret name, and username and password keys to use for each of the file systems. It should have 4 fields:
- fsxId - Set to the AWS File System ID.
- secretName - Set to the name of the secret created in step one.
- usernameKey - Set to the name of the key that holds the username.
- passwordKey - Set to the name of the key that holds the password.

### S3 Bucket File formats
#### Partners file
The partners file is a comma separated values file with the following fields:
- FSxN Id - Set to the AWS file system ID.
- SVM Name - Set to the SVM name.
- Partner FSxN ID - Set to the AWS ID the partner FSxN file system.
- Partner FSxN IP - Set to the IP address of the management port of the partner FSxN file system.
- Partner SVM Name - The name of the SVM where you want the SnapMirror destination volume to reside.
- Partner SVM Source Name - Is the "local name" of the source SVM. Usually, it is the same as the source SVM, but can be different if that same name already exists on the partner file system. When you peer the SVM it will require you to create an alias for the source SVM so all the SVM names are unique.

Example File:
```
fs-04f0ebeeXXXXXXXXX,fsx,fs-07bcb7adXXXXXXXXX,198.19.254.83,fsx,prod-fsx
fs-04f0ebeeXXXXXXXXX,smb_svm,fs-07bcb7adXXXXXXXXX,198.19.254.83,fsx,smb_svm
```

#### Secrets file
The secret file is a comma separated values file with the following fields:
- fsxId - Set to the AWS File System ID.
- Secret Name - Set to the name of the secret created in step one.
- Username Key - Set to the name of the key that holds the username.
- Password Key - Set to the name of the key that holds the password.

Example File:
```
fs-04f0ebeeXXXXXXXXX,FSxSecret-Default,username,password
fs-07bcb7adXXXXXXXXX,FSxSecret-Default,username,password
```

### Required permissions
Here are the permissions that are required for the program to run:

|Action|Resource|Description|
|-|:-:|-|
|fsx:DescribeFileSystems| `*` | Allows the program to discovery the file systems.|
|fsx:DescribeVolumes| `*` | Allows the program to discovery the volumes within the file systems.|
|tag:GetResources|`*` | Allows the program to get tag information.|
|ec2:DescribeRegions| `*` | Allow it to discovery all the regions.|
|secretsmanager:GetSecretValue| pattern that matches the required secrets | Allows the program to obtain the credentials for the file systems.|
|s3:GetObject| ARN of the bucket to get the partners and secrets files from | Not required if you aren't using an S3 bucket to store the partners and secrets ARN information.|
|s3:ListBucket| ARN of the bucket to get the partners and secrets files from | Not required if you aren't using an S3 bucket to store the partners and secrets ARN information.|
|dynamodb:DescribeTable | ARN of the DynamoDB tables that holds the partner and secrets ARN information.| Allows the program to access the table. |
|dynamodb:Scan | ARN of the DynamoDB tables that holds the partner and secrets ARN information.| Allows the program to get the contents from the table. |

If running as a Lambda function you will also need to attached an AWS Managed Policy named `AWSLambdaVPCAccessExecutionRole`. This managed policy is required for a function that is to run within a VPC.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
