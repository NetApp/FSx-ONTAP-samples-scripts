# FSxN Report

## Introduction
This sample is used to generate a report of all the FSx for ONTAP file systems in your AWS account.
It provides information about the file systems, volumes and storage virtual machines (SVMs).
It can generate either an HTML or Textual based report. The HTML report is suitable for being
sent in an email message (i.e. using "in-line styles"). And finally, it can either
output the report to "standard out" or be send to an email address using AWS Simple Email Service (SES).

It is a Python program that can be run either standalone or as a Lambda function. The
following environment variables can be set to control the behavior of the program:
- `TO_ADDRESS`: The email address(es) to send the report to. Can be a CSV list. Each address must be a verified email address in AWS SES. If one is not, all will fail.
- `FROM_ADDRESS`: The email address to send the report from. This must also be a verified email address in AWS SES.
- `ALL_REGIONS`: If set to `true`, the program will scan all AWS regions for FSx for ONTAP file systems. If not set, it will only scan the regions specified in the `REGIONS` variable.
- `REGIONS`: A comma-separated list of AWS regions to scan for FSx for ONTAP file systems.
- `REPORT_TYPE`: The type of report to generate. Can be either `html` or `text`. Defaults to `html`.

If you want the program to run on a regular basis, and send you an email with the report, it is
recommended to deploy it as a Lambda function with an EventBridge rule to trigger it on a schedule (e.g. daily, weekly, monthly, etc.).

## Deployment
To ease with the deployment, a CloudFormation template has been provided. It will:
- Create a Lambda function with the program also found in this repository
- Create a AWS IAM role with the required permissions. It does allow you to specific an ARN for your own role if you don't want the CloudFormation template to create one.
- Create a EventBridge rule to trigger the Lambda function on a schedule.

To use the template, just download the [cloudformation.yaml](cloudformation.yaml) file and:
1. Go to the CloudFormation service of the AWS console.
2. Click on "Create stack" and select "With new resources (standard)."
3. Select "Upload a template file" and upload the `cloudformation.yaml` file.
4. Click "Next" and provide and provide the following information:
    |Parameter Name|Note|
    |---|---|
    |Stack name|A name for the stack, e.g., `FSxNReportStack`.|
    |emailTo|The AWS SES identity that you want to send the report to. This must be a verified email address in AWS SES.|
    |emailFrom|The AWS SES identity that you want to send the report from. This must also be a verified email address in AWS SES.|
    |reportType|The type of report to generate. Can be either `html` or `text`. Defaults to `html`.|
    |frequency|The frequency at which the report should be generated. Allowed values are `daily`, `weekly`, `monthly`. Defaults to `weekly`.|
    |regions|A comma-separated list of AWS regions to scan for FSx for ONTAP file systems. If not provided, it will default to the region where the stack is created.|
    |allRegions|If set to `true`, the program will scan all AWS regions for FSx for ONTAP file systems.|
    |roleArn|(optional) The ARN of an existing IAM role to use for the Lambda function. If not provided, the CloudFormation template will create a new role with the required permissions.|
5. Click "Next" and review the stack details and acknowledge that an IAM role might be created. It won't if you provided a role ARN in the previous step.
6. Click "Next".
7. Finally, "Create stack".

Once the stack has been created, you should start getting the report emailed to the email address you provided
at the frequency you specified. If you want to force a report to be generated, just go to the Lambda function
and click on `Test`. You'll also see any error messages if something goes wrong.

If you want to create your own role, here are the minimum permissions required: 
|Permission | Minimal Resources | Notes |
|---|:---:|---|
|`fsx:describe_file_systems`| `*` | Needed to list all FSx for ONTAP file systems in the account. |
|`fsx:describe_volumes`| `*` | Needed to list all volumes in the account. |
|`fsx:describe_storage_virtual_machines`| `*` | Needed to list all volumes and SVMs in the account. |
|`cw:get_metric_data`| `*` | Needed to get the metrics for the file systems. |
|`ec2:describe_region`| `*` | Needed to list all AWS regions. |
|`ses:send_email`| `arn:aws:ses:${AWS_REGION}:${AWS_ACCOUNT}:identity/${EMAIL_ADDRESS}`<br>`arn:aws:ses:${AWS_REGION}:${AWS_ACCOUNT}:configuration-set/${EMAIL_ADDRESS}`| Recommend just using `*` for the email addresses, otherwise you'll need a resource line for each `To` and `From` email address. |

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
