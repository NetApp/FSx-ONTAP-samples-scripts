# Ingest FSx for ONTAP NAS audit logs into CloudWatch

## Overview
This sample demonstrates a way to ingest the NAS audit logs from an FSx for Data ONTAP file system into a CloudWatch log group
without having to NFS or CIFS mount a volume to access them.
It will attempt to gather the audit logs from all the SVMs within all the FSx for Data ONTAP file systems that are within a specified region.
It will skip any file systems where the credentials aren't provided in the supplied AWS SecretManager's secret, or that do not have
the appropriate NAS auditing configuration enabled.
It will maintain a "stats" file in an S3 bucket that will keep track of the last time it successfully ingested audit logs from each
SVM to try to ensure it doesn't process an audit file more than once.
You can run this script as a standalone program or as a Lambda function. These directions assume you are going to run it as a Lambda function.
**NOTE**: There are two ways to install this program. Either with the [CloudFormaiton script](cloudformation-template.yaml) found this this repo,
or by following the manual instructions found in the this file.

## Prerequisites
- An FSx for Data ONTAP file system.
- An S3 bucket to store the "stats" file and a Lambda layer zip file.
    - You will need to download the [Lambda layer zip file](https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/ingest_nas_audit_logs_into_cloudwatch/lambda_layer.zip) from this repo and upload it to the S3 bucket. Be sure to perserve the name `lambda_layer.zip`.
    - The "stats" file is maintained by the program. It is used to keep track of the last time the Lambda function successfully ingested audit logs from each SVM. Its size will be small (i.e. less than a few megabytes).
- A CloudWatch log group to ingest the audit logs into. Each audit log file with get its own log stream within the log group.
- Have NAS auditing configured and enabled on the SVM within a FSx for Data ONTAP file system. **Ensure you have selected the XML format for the audit logs.** Also,
ensure you have set up a rotation schedule. The program will only act on audit log files that have been finalized, and not the "active" one. You can read this
[knowledge based article](https://kb.netapp.com/on-prem/ontap/da/NAS/NAS-KBs/How_to_set_up_NAS_auditing_in_ONTAP_9) for instructions on how to setup NAS auditing.
- Have the NAS auditing configured to store the audit logs in a volume with the same name in all SVMs on all the FSx for Data ONTAP file
systems that you want to ingest the audit logs from.
- An AWS Secrets Manager secret that contains the credentials you want to use to obtain the NAS Audit logs with for all the FSxN file systems.
  - The secret should be in the form of key/value pairs where the key is the file system ID and value is a dictionary with the keys `username` and `password`. For example:
```json
      {
        "fs-0e8d9172fa5411111": {"username": "fsxadmin", "password": "superSecretPassword"},
        "fs-0e8d9172fa5422222": {"username": "service_account", "password": "superSecretPassword"}
      }
```
- You have applied the necessary SACLs to the files you want to audit. The knowledge base article linked above provides guidance on how to do this.

- AWS Endpoints. Since the Lambda function runs within your VPC it will not have access to the Internet, even if you can access the Internet from the Subnet it runs from.
Therefore, there needs to be an VPC endpoint for all the AWS services that the Lambda function uses. Specifically, the Lambda function needs to be able to access the following AWS services:
  - FSx.
  - Secrets Manager.
  - CloudWatch Logs.
  - S3 - Note that typically there is a Gateway type VPC endpoint for S3, so you should not need to create a VPC endpoint for S3.
- Role for the Lambda function. Create a role with the necessary permissions to allow the Lambda function to do the following:

<!--- Using HTML to create a table that has rowspan attributes since the markdown table syntax does not support that. --->
<table>
<tr><th>Service</td><th>Actions</td><th>Resources</th></tr>
<tr><td>Fsx</td><td>fsx:DescribeFileSystems</td><td>&#42;</td></tr>
<tr><td rowspan="3">ec2</td><td>DescribeNetworkInterfaces</td><td>&#42;</td></tr>
<tr><td>CreateNetworkInterface</td><td rowspan="2">arn:aws:ec2:&lt;region&gt;:&lt;accountID&gt;:&#42;</td></tr>
<tr><td>DeleteNetworkInterface</td></tr>
<tr><td rowspan="3">CloudWatch Logs</td><td>CreateLogGroup</td><td rowspan="3">arn:aws:logs:&lt;region&gt;:&lt;accountID&gt;:log-group:&#42;</td></tr>
<tr><td>CreateLogStream</td></tr>
<tr><td>PutLogEvents</td></tr>
<tr><td rowspan="3">s3</td><td> ListBucket</td><td> arn:aws:s3:&lt;region&gt;:&lt;accountID&gt;:&#42;</td></tr>
<tr><td>GetObject</td><td rowspan="2">arn:aws:s3:&lt;region>:&lt;accountID&gt;:&#42;/&#42;</td></tr>
<tr><td>PutObject</td></tr>
<tr><td>Secrets Manager</td><td> GetSecretValue </td><td>arn:aws:secretsmanager:&lt;region&gt;:&lt;accountID&gt;:secret:&lt;secretName&gt&#42;</td></tr>
</table>
Where:

- &lt;accountID&gt; -  is your AWS account ID.
- &lt;region&gt; - is the region where the FSx for ONTAP file systems are located.
- &lt;secretName&gt; - is the name of the secret that contains the credentials for the fsxadmin accounts.

Notes:
- Since the Lambda function runs within your VPC it needs to be able to create and delete network interfaces.
- The AWS Security Group Policy builder incorrectly generates resource lines for the `CreateNetworkInterface`
and `DeleteNetworkInterface` actions. The correct resource line is `arn:aws:ec2:<region>:<accountID>:*`.
- It needs to be able to create a log groups so it can create a log group for the diagnostic output from the Lambda function.
- Since the ARN of any Secrets Manager secret has random characters at the end of it, you must add the `*` at the end, or provide the full ARN of the secret.

## Deployment
1. Create a Lambda deployment package by:
    1. Downloading the [ingest_nas_audit_logs.py](ingest_nas_audit_logs.py) file from this repository and placing it in an empty directory.
    1. Rename the file to `lambda_function.py`.
    1. Install a couple dependencies that aren't included with AWS's base Lambda runtime by executing the following command:<br>
`pip install --target . xmltodict requests_toolbelt`<br>
    1. Zip the contents of the directory into a zip file.<br>
`zip -r ingest_nas_audit_logs.zip .`<br>

2. Within the AWS console, or using the AWS API, create a Lambda function with:
    1. Python 3.10, or higher, as the runtime.
    1. Set the permissions to the role created above.
    1. Under `Additional Configurations` select `Enable VPC` and select a VPC and Subnet that will have access to all the FSx for ONTAP
file system management endpoints that you want to gather audit logs from. Also, select a Security Group that allows TCP port 443 outbound.
Inbound rules don't matter since the Lambda function is not accessible from a network.
    1. Click `Create Function` and on the next page, under the `Code` tab, select `Upload From -> .zip file.` Provide the .zip file created by the steps above. 
    1. From the `Configuration -> General` tab set the timeout to at least 30 seconds. You will may need to increase that if it has to
process a lot of audit entries and/or process a lot of SVMs.

3. Configure the Lambda function by setting the following environment variables. For a Lambda function you do this by clicking on the `Configuration` tab and then the `Environment variables` sub tab.

| Variable | Description |
| --- | --- |
| fsxRegion | The region where the FSx for ONTAP file systems are located. |
| secretArn | The ARN of the secret that contains the credentials for all the FSx for ONTAP file systems you want to gather audit logs from. |
| s3BucketRegion | The region of the S3 bucket where the stats file is stored. |
| s3BucketName | The name of the S3 bucket where the stats file is stored. |
| statsName | The name you want to use as the stats file. |
| logGroupName | The name of the CloudWatch log group to ingest the audit logs into. |
| volumeName | The name of the volume, on all the FSx for ONTAP file systems, where the audit logs are stored. |

4. Test the Lambda function by clicking on the `Test` tab and then clicking on the `Test` button. You should see "Executing function: succeeded".
If not, click on the "Details" button to see what errors there are.

5. After you have tested that the Lambda function is running correctly, add an EventBridge trigger to have it run periodically.
You can do this by clicking on the `Add Trigger` button within the AWS console on the Lambda page and selecting `EventBridge (CloudWatch Events)`
from the drop-down menu. You can then configure the schedule to run as often as you want. How often depends on how often you have
set up your FSx for ONTAP file systems to rotate audit logs, and how up-to-date you want the CloudWatch logs to be.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
