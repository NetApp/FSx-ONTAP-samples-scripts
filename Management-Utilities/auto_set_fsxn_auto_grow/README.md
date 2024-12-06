# Automatically Set Auto Size mode to Grow on FSx for NetApp ONTAP Volumes

## Introduction
This sample shows one way to mitigate the issue of not being able to set the auto size mode
on an FSx for ONTAP volume when creating it from the AWS console or API. It does this by providing
a Lambda function that will set the mode for you, and instructions on how to set up a
CloudWatch event to trigger the Lambda function whenever a volume is created. With this
combination it ensures that all volumes are effectively created with the auto size mode
set up the way you want for all volumes.

Note that a CloudWatch event is not created when a volume is created directly from the
ONTAP side, either using the ONTAP CLI, System Manager, or REST API. So, it is assumed
if you are creating them that way, that you will set them with the auto size mode set
the way you want.

Note that since the Lambda function has to communicate with the FSx for ONTAP management
endpoint, it has to run within a VPC that has that connectivity. Because of the way
AWS allows a Lambda function to run within a VPC, it will not have access to the Internet
even if normally from that subnet it is running in would. Therefore, you will have to set up
VPC endpoints for the AWS services that the Lambda function will need to communicate with.
This includes:
- FSx
- AWS Secrets Manager
- DynamoDB if you are using it to store the secrets table

These endpoints are created for you if you use the CloudFormation template provided in this
repository. If you are setting up the Lambda function manually, you will have to create
these endpoints yourself.

The way this script authenticates to the FSx for ONTAP management endpoint is by using
the credentials stored in AWS Secrets Manager. Since it can manage multiple FSxN file
systems a table is used to specify which secret to use for each file system. This `secretsTable`
can either be stored in a DynamoDB table, or just hard coded in the source code of the
Lambda function. The schema for the `secretsTable` is as follows:
```json
[
    {"fsxId": "fs-XXXXXXXXXXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
    {"fsxId": "fs-XXXXXXXXXXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
    {"fsxId": "fs-XXXXXXXXXXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"},
    {"fsxId": "fs-XXXXXXXXXXXXXXXXX", "secretName": "fsxn-credentials", "usernameKey": "username", "passwordKey": "password"}
]
```
Where the values associated with each key are as follows:

| Key | Value | Example Value shown above|
|:----|:------| :------------------------|
| `fsxId` | The ID of the FSxN file system. | `fs-XXXXXXXXXXXXXXXXX` |
| `secretName` | The name of the secret in Secrets Manager. | `fsxn-credentials` |
| `usernameKey` | The key in the secret that contains the username. | `username` |
| `passwordKey` | The key in the secret that contains the password. | `password` |

## Deployment
There are two ways to deploy this script. The first way to is use the CloudFormation
template provided in the cloudformation.yaml file. The second way is to follow the
steps in the "Manual Setup" section below.

### CloudFormation Deployment
Copy the `cloudformation.yaml` file to your local machine. Then, go to the CloudFormation
service in the AWS console, and click on "Create stack." Select the "Upload a template file"
option and upload the `cloudformation.yaml` file. Click "Next."

On the next page, give the stack a name. Note that this name is used as a suffix to most of the resources it creates
so you might want to keep it short, but meaningful. After the stack name you will need to fill in the following parameters:

| Parameter Name | Description |
|:--------------|:------------|
| subNetIds| List the subnets that you want the Lambda function to run in. They must have connectivity to the FSxN file systems management endpoints. |
| vpcId | The VPC that contains the subnets. This is only used if you are having this CloudFormation template create the AWS service VPC endpoints. |
| securityGroupIds | The security group that the Lambda function will use. This security group should allow access to the AWS service endpoints and the FSx for ONTAP management endpoint over TCP port 443. |
| dynamoDbSecretsTableName | The name of the DynamoDB table that contains the `secretsTable` described above. This value is optional, but if not set, the table commented out in the code will have to be updated to provide the needed information.|
| dynamoDbRegion| The region where the DynamoDB table is located. |
| secretsManagerRegion| The region where the AWS Secrets Manager secrets are located. |
| createWatchdogAlarm | If set to `true` a CloudWatch alarm will be created that will trigger if the Lambda function fails while trying to set the auto size mode on a volume. |
| snsTopicArn| The ARN of the SNS topic that the CloudWatch alarm will send a message to if the Lambda function fails. |
| createSecretManagerEndpoint| If set to `true` a Secrets Manager VPC endpoint will be created. |
| createFSxEndpoint| If set to `true` a FSx VPC endpoint will be created. |
| createDynamoDbEndpoint| If set to `true` a DynamoDB VPC endpoint will be created. |
| routeTableIds| Since the DynamoDB endpoint is a `Gateway` type, routing tables have to be updated to use it. Set this parameter to any route table IDs you want updated. |
| endpointSecurityGroupIds| The security group that the VPC endpoints will use. This security group should allow access to the AWS service the endpoints from the Lambda function over port 443. Since the Lambda function will have the security group specified above assigned to it, it can be used as a network `source` for this security group. |
| autoSizeMode| The auto size mode you want to set the volume to. Valid values are: `grow`, `grow_shrink`, and `off`. |
| growThresholdPrecentage| The percentage of the volume that must be used before a volume will grow. |
| maxGrowSizePercentage| The maximum size the volume can auto grow to expressed in terms of a percentage of the initial volume size. |
| shrinkThresholdPrecentage| The percentage of the volume that must be used before a volume will shrink. |
| minShrinkSizePercentage| The minimum size the volume can auto shrink to expressed in terms of a percentage of the initial volume size. |
| maxWaitTime| The maximum time, in seconds, that the script will wait for the volume to be created before it will give up and exit. This can happen if a lot of volumes are created at the same time. |

Once you have filled in these parameters, click `Next`. On the next page you must accept that this
script can, and does, create roles. Click `Next`. Finally, on the last page, you can review the stack and click `Submit`.

After the stack has been created everything should be ready. To test, simply create a volume in the
AWS console and check from the ONTAP CLI that auto size mode appropriately. If it isn't set, check the CloudWatch
logs for the Lambda function to see what went wrong. You can quickly go to the correct Lambda
function by clicking on the Resources tab within the CloudFormation stack and clicking on the
link to the Lambda function.

### Manual Setup
If for some reason you can't run the CloudFormation template, here are the steps you can use to manually setup the service:

#### Create secrets in AWS Secrets Manager
Create a secret in Secrets Manager for each of the FSxN file systems you want to manage with
this script. Each secret should have two key value pairs. One that specifies the
user account to use when issuing API calls, and the other that specifies the password for
that account. Note that if you use the same username and password, it is okay
to use the same secret for multiple file systems.

#### Create a role for the Lambda function
The Lambda function doesn't leverage that many AWS services, so only a few permissions are required:

| Permission              | Minimal Scope     |  Notes 
|:------------------------|:----------------|:----------------|
| Allow:logs:CreateLogGroup | arn:aws:logs:\<LAMBDA_REGION>:\<ACCOUNT_ID>:* | This is required so you can get logs from the Lambda function. |
| Allow:logs:CreateLogStream<BR>Allow:logs:PutLogEvents | arn:aws:logs:\<LAMBDA_REGION>:\<ACCOUNT_ID>:/aws/lambda/\<LAMBDA_FUNCTION_NAME>:* | This is required so you can get logs from the Lambda function. |
| Allow:secretsmanager:GetSecretValue | \<ARNs_OF_SECRETS_WITHIN_SECRETS_MANAGER> | This is required so the Lambda function can get the credentials for the FSxN file system. |
| Allow:dynamodb:Scan | \<ARN_OF_DYNAMODB_TABLE> | This is optional, depending on if you put your `secretsTable` in a DynamoDB table. |
| Allow:fsx:DescribeFileSystems<BR>Allow:fsx:DescribeVolumes | * | You can't limit the scope of these APIs. They are required to get information regarding the file system and volumes. |
| Allow:ec2:CreateNetworkInterface<BR>Allow:ec2:DeleteNetworkInterface<BR>Allow:ec2:DescribeNetworkInterfaces | * | Since the Lambda function is going to run within your VPC, it has to be able to create a network interface to communicate with the FSxN file system endpoints. |

#### Create AWS Endpoints
Since the Lambda function will be configured to run within a VPC that can communicate with the FSxN
file systems, so it can issue API calls against them, there will need to be AWS endpoints so
the Lambda function can also access some of the AWS services. If you have a Transit Gateway setup
that allows access to the Internet, you may not have to create these endpoints, otherwise, the
following endpoints will need to be created, and attached to the VPC and subnets that the Lambda
function will run in:

- FSx
- SecretsManager
- DynamoDB - You only need this one if you are going to store your `secretsTable` in DynamoDB. It is recommended that this be a `Gateway` type endpoint. However, if you do that you will also have to update the routing tables associated with the subnets that the Lambda function is deployed on in order for the Lambda function to be able to use it.

#### Create the Lambda Function
Create a Lambda function with the following parameters:

- Authored from scratch.
- Use the Python runtime.
- Set the permissions to the role created above.
- Enable VPC. Found under the Advanced Settings.
    - Attached to the VPC that can communicate with the FSxN file systems.
    - Attached to the Subnets that can communicate with the FSxN file systems.
    - Attached to a security group that allows access from any IP within the two subnets over port 443.

After you create the function, you will be able to insert the code included with this 
sample into the code box. Once you have inserted the code, modify the definitions
of the following variables to suit your needs:
- secretsTable - This is an array that defines the secrets created above. Each element in the array
is a dictionary with the following keys:
    - secretName - The name of the secret in Secrets Manager.
    - usernameKey - The name of the key in the secret that contains the username.
    - passwordKey - The name of the key in the secret that contains the password.

    **NOTE:** Instead of defining the secretsTable in the script, you can define
dynamoDbSecretsTableName and dynamoDbRegion and the script will read in the
secretsTable information from the specified DynamoDB table. The table should have
the same fields as the `secretsTable` defined above.

- secretsManagerRegion - Defines the region where your secrets are stored.
- autoSizeMode - Defines the auto size mode you want to set the volume to. Valid values are:
    - grow - The volume will automatically grow when it reaches the grow threshold.
    - grow_shrink - The volume will automatically grow, and shrink when it reaches the shrink threshold.
    - off - The volume will not automatically grow or shrink.
- growThresholdPercentage - The percentage of the volume that must be in use before the volume will grow.
- maxGrowSizePercentage - The maximum size the volume can auto grow to, expressed in terms of a percentage of the initial volume size.
- shrinkThresholdPercentage - The percentage of the volume that must be in use before the volume will shrink.
- minShrinkSizePercentage - The minimum size the volume can auto shrink to, expressed in terms of a percentage of the initial volume size.
- maxWaitTime - The maximum time, in seconds, the script will wait for the volume to be created before it will give up and exit.

**NOTE:** Do not delete the variables or set them to None or empty strings, as the script will not run properly if done so.

Once you have updated the program, click on the "Deploy" button.

Next, click on the Configuration tab, then General and set the timeout to 2 minutes, or
two times the number of seconds you set the `maxWaitTime` variable. Note that typically
the program will not run this long, but if there are a lot of volumes being created at the
same time, it may have to wait a while for the volume to get created on the ONTAP side before
it can set the auto size mode.

#### Create an Event Bridge Rule (a.k.a. CloudWatch Event) that will trigger when a FSx Volume is created
Once on the "Event Bridge" page, click on Rules on the left-hand side. From there click
on Create Rule. Give the rule a name, and make sure to put the rule on the "Default" bus.
Finally select "Rule with an event pattern" and click Next.

Select "other" as the event source, skip pass the "Sample Event" section, and click on
"Custom pattern (JSON editor)" under the Creation Method paste the following in the
`Edit Event Pattern` text box:
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

Click `Next`. The next page will allow you to select the Lambda function you created above.
Just take the defaults for the remaining pages and click on "Create Rule."

At this point every time a volume is created the Lambda function will be called, and it will
attempt to set the auto size mode as specified via the variables at the top of the code.
To confirm it is working, create a volume in the AWS console and check the auto size mode
from the ONTAP CLI. If it isn't set, check the CloudWatch logs for the Lambda function to
see what went wrong.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
