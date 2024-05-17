# Automatically Set Auto Size mode to Grow on FSx for NetApp ONTAP Volumes

## Introduction
This project helps to mitigate the issue of not being able to set the auto size mode to
'grow' when creating a FSxN volume from the AWS console or API. It does this by providing
a Lambda function that will set the mode for you, and instructions on how to set up a
CloudWatch event to trigger the Lambda function whenever a volume is created. With this
combination it ensures that all volumes are effectively created with the auto size mode
set to 'grow'.

## Set Up
There are just a few things you have to do to set this up:

### Create a role for the Lambda function
The Lambda function doesn't leverage that many AWS services, so only a few permissions are required:


| Permission              | Minimal Scope     |  Notes 
|:------------------------|:----------------|:----------------|
| Allow:logs:CreateLogGroup | arn:aws:logs:<LAMBDA_REGION>:<ACCOUNT_ID>:* | This is required so you can get logs from the Lambda function. |
| Allow:logs:CreateLogStream<BR>Allow:logs:PutLogEvents | arn:aws:logs:<LAMBDA_REGION>:<ACCOUNT_ID>:/aws/lambda/<LAMBDA_FUNCTION_NAME>:* | This is required so you can get logs from the Lambda function. |
| Allow:secretsmanager:GetSecretValue | <ARN_OF_SECRET_WITHIN_SECRETS_MANAGER> | This is required so the Lambda function can get the credentials for the FSxN file system. |
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

### Create the Lambda Function
Create a Lambda function with the following parameters:

- Authored from scratch
- Uses the Python runtime
- Set the permissions to the role created above.
- Enable VPC. Found under the Advanced Settings
  - Attached to the VPC that contains the FSxN file system
  - Attached to the Subnets that contain the FSxN file system.
  - Attached a security group that allows access from any IP within the two subnets.

After you create the function, you will be able to insert the code included with this 
projrectinto the code box. Once you have inserted the code, modify the "secretsTable"
array to provide the secrets name, and the keys for the username as password for each
of the FSxN File Systems that you want to manage with this script. Also, set the
secretsManagerRegion variable to the region where your secrets are stored.

Once you have updated the program, click on the "Deploy" button.

Next, click on the Configuration tab, then General and set the timeout to 10 seconds.

### Create an Event Bridge Rule (a.k.a. Cloud Watch Event) that will trigger when a FSx Volume is created
Once on the "Event Bridge" page, click on Rules on the left add side. From there click
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

This point every time a volume is created the Lambda function will be called, and it will
set the auto size mode to "grow".

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.