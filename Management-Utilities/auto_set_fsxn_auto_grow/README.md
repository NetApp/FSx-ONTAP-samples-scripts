# Automatically Set Auto Size mode to Grow on FSx for NetApp ONTAP Volumes

## Introduction
This sample shows one way to mitigate the issue of not being able to set the auto size mode
on an FSxN volume when creating it from the AWS console or API. It does this by providing
a Lambda function that will set the mode for you, and instructions on how to set up a
CloudWatch event to trigger the Lambda function whenever a volume is created. With this
combination it ensures that all volumes are effectively created with the auto size mode
set up the way you want for all volumes.

## Set Up
There are just a few things you have to do to set this up:

### Create secrets in AWS Secrets Manager
Create a secret in Secrets Manager for each of the FSxN file systems you want to manage with
this script. Each secret should have two key value pairs. One that specifies the
user account to use when issuing API calls, and the other that specifies the password for
that account. Note that if you use the same username and password, it is okay
to use the same secret for multiple file systems.

### Create a role for the Lambda function
The Lambda function doesn't leverage that many AWS services, so only a few permissions are required:


| Permission              | Minimal Scope     |  Notes 
|:------------------------|:----------------|:----------------|
| Allow:logs:CreateLogGroup | arn:aws:logs:<LAMBDA_REGION>:<ACCOUNT_ID>:* | This is required so you can get logs from the Lambda function. |
| Allow:logs:CreateLogStream<BR>Allow:logs:PutLogEvents | arn:aws:logs:<LAMBDA_REGION>:<ACCOUNT_ID>:/aws/lambda/<LAMBDA_FUNCTION_NAME>:* | This is required so you can get logs from the Lambda function. |
| Allow:secretsmanager:GetSecretValue | <ARN_OF_SECRET_WITHIN_SECRETS_MANAGER> | This is required so the Lambda function can get the credentials for the FSxN file system. |
| Allow:dynamodb:Scan | <ARN_OF_DYNAMODB_TABLE> | This is optional, depending on if you put your secretsTable in a DynamoDB. |
| Allow:fsx:DescribeFileSystems<BR>Allow:fsx:DescribeVolumes | * | You can't limit these API. They are required to get information regarding the file system and volumes. |
| Allow:ec2:CreateNetworkInterface<BR>Allow:ec2:DeleteNetworkInterface<BR>Allow:ec2:DescribeNetworkInterfaces | * | Since the Lambda function is going to run within your VPC, it has to be able to create a network interface to communicate with the FSxn file system API. |

### Create AWS Endpoints
Since the Lambda function will be configured to run within the VPC that contains the FSxN
file system, so it can issue API calls against it, there will need to be AWS endpoints so
the Lambda function can access some of the AWS service. If you have a Transit Gateway setup
that allows access to the Internet, you may not have to create these endpoints, otherwise, the
following endpoints will need to be created, and attached to the VPC and subnets that the
FSxN file system is attached to.

- FSx
- SecretsManager
- DynamoDB - This one can be a Gateway endpoint.

### Create the Lambda Function
Create a Lambda function with the following parameters:

- Authored from scratch.
- Uses the Python runtime.
- Set the permissions to the role created above.
- Enable VPC. Found under the Advanced Settings.
    - Attached to the VPC that contains the FSxN file system
    - Attached to the Subnets that contain the FSxN file system.
    - Attached a security group that allows access from any IP within the two subnets.

After you create the function, you will be able to insert the code included with this 
sample into the code box. Once you have inserted the code, modify the definitions
of the following variables to suit your needs:
- secretsTable - This is an array that defines the secrets created above. Each element in the array
is a dictionary with the following keys:
    - secretName - The name of the secret in Secrets Manager.
    - usernameKey - The name of the key in the secret that contains the username.
    - passwordKey - The name of the key in the secret that contains the password.

    **NOTE:** Instead of defining the secretsTable in the script, you can define
dynamodbSecretsTableName and dynamodbRegion and the script will read in the
secretsTable information from the specified DynamoDB table. The table should have
the same fields as the secretsTable defined above.

- secretsManagerRegion - Defines the region where your secrets are stored.
- autoSizeMode - Defines the auto size mode you want to set the volume to. Valid values are:
    - grow - The volume will automatically grow when it reaches the grow threshold.
    - grow_shrink - The volume will automatically grow, and shrink when it reachs the shrink threshold.
    - off - The volume will not automatically grow or shrink.
- growThresholdPercentage - The percentage of the volume that must be used before the volume will grow.
- maxGrowSizePercentage - The maximum size the volume can auto grow to expressed in terms of a percentage of the volume size. The default is 200%.
- shrinkThresholdPercentage - The percentage of the volume that must be used before the volume will shrink.
- minShrinkSizePercentage - The minimum size the volume can auto shrink to expressed in terms of a percentage of the volume size. The default is 50%.
- maxWaitTime - The maximum time, in seconds, the script will wait for the volume to be created before it will give up and exit.

**NOTE:** Do not delete the variables or set them to None or empty
strings, as the script will not run properly if done so.

Once you have updated the program, click on the "Deploy" button.

Next, click on the Configuration tab, then General and set the timeout to 2 minutes, or
two times the number of seconds you set the maxWaitTime variable. Note that typically
the program will not run this long, but if there are a lot of volumes being created at the
same time, it may have to wait a while for the volume to get created on the ONTAP side before
it can set the auto size mode.

### Create an Event Bridge Rule (a.k.a. CloudWatch Event) that will trigger when a FSx Volume is created
Once on the "Event Bridge" page, click on Rules on the left-hand side. From there click
on Create Rule. Give the rule a name, and make sure to put the rule on the "Default" bus.
Finally select "Rule with an event pattern" and click Next.

Select "other" as the event source, skip pass the "Sample Event" section, and click on
"Custom pattern (JSON editor)" under the Creation Method. Paste the following in the
Edit Event Pattern text box:
```json
{
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "fsx.amazonaws.com"
    ],
    "eventName": [
      "CreateVolume"
    ]
  }
}
```

Click Next. This next page will allow you to select the Lambda function you created above.
Just take the defaults for the remaining pages and click on "Create Rule."

At this point every time a volume is created the Lambda function will be called, and it will
attempt to set the auto size mode as specified via the variables at the top of the code.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
