# Ingest FSx for ONTAP NAS audit logs into CloudWatch

## Overview
This sample will demonstrate a way to ingest the NAS audit logs from an FSx for Data ONTAP file system into a CloudWatch log group
without having to NFS or CIFS mount a volume to access them.
It will attempt to gather the audit logs from all the FSx for Data ONTAP file systems that are within a specified region.
It will skip any file systems where the credentials aren't provided in the supplied AWS SecretManager's secret, or that do not have
the appropriate NAS auditing configuration enabled.
It will maintain a "stats" file in an S3 bucket that will keep track of the last time it successfully ingested audit logs from each
file system to try and ensure it doesn't process an audit file more than once..
You can run this program as a standalone program or as a Lambda function. These directions assume you are going to run it as a Lambda function.

## Prerequisites
- An FSx for Data ONTAP file system.
- Have NAS auditing configured and enabled on the FSx for Data ONTAP file system. Ensure you have selected the XML format for the audit logs. You can read this
[knowledge based article](https://kb.netapp.com/on-prem/ontap/da/NAS/NAS-KBs/How_to_set_up_NAS_auditing_in_ONTAP_9) for instructions on how to setup NAS auditing.
- Have the NAS auditing configured to store the audit logs in a volume with the same name on all FSx for Data ONTAP file
systems that you want to ingest the audit logs from.
- A CloudWatch log group.
- An AWS Secrets Manager secret that contains the passwords for the fsxadmin account for all the FSx for Data ONTAP file system you want to gather audit logs from.
  - The secret should be in the form of key/value pairs (or a JSON object) where the key is the file system ID and value is the password for the fsxadmin account. For example:
```json
      {
        "fs-1234567890abcdef0": "password1",
        "fs-abcdef012345"     : "password2"
      }
```
- You have applied the necessary  SACLS to the files you want to audit.
- You have created a role with the necessary permissions to allow the Lambda function to do the following:

<table>
<tr><th>Service</td><th>Actions</td><th>Resources</th></tr>
<tr><td>fsx</td><td>fsx:DescribeFileSystems</td><td>*</td></tr>
<tr><td rowspan="3">ec2</td><td>DescribeNetworkInterfaces</td><td>*</td></tr>
<tr><td>CreateNetworkInterface</td><td>arn:aws:ec2:*:&lt;accountID&gt;:*</td></tr>
<tr><td>DeleteNetworkInterface</td><td>arn:aws:ec2:*:&lt;accountID&gt;:*</td></tr>
<tr><td rowspan="2">logs</td><td>CreateLogStream        </td><td> arn:aws:logs:&lt;region&gt;:&lt;accountID&gt;:log-group:&lt;logGroupName&gt;:* </td></tr>
<tr><td>PutLogEvents           </td><td> arn:aws:logs:&lt;region&gt;:&lt;accountID&gt;:log-group:&lt;logGroupName&gt;:* </td></tr>
<tr><td rowspan="3"> s3  </td><td> ListBucket             </td><td> arn:aws:s3:&lt;region&gt;:&lt;accountID&gt;:* </td></tr>
<tr><td>GetObject              </td><td> arn:aws:s3:&lt;region>:&lt;accountID&gt;:*/* </td></tr>
<tr><td>PutObject              </td><td> arn:aws:s3:&lt;region>:&lt;accountID&gt;:*/* </td></tr>
<tr><td>secretsmanager </td><td> GetSecretValue </td><td> arn:aws:secretsmanager:&lt;region&gt;:&lt;accountID&gt;:secret:&lt;secretName&gt;</td></tr>
</table>

## Deployment
1. Create a Lambda deployment package by:
    a. Downloading the `ingest_fsx_audit_logs.py` file from this repository and placing it in an empty directory.
    b. Rename the file to `lambda_function.py`.
    c. Install a couple dependencies that aren't included with AWS's base Lambda deployment by running the following command:
```bash
       pip install --target . xmltodict requests_toolbelt
```
    d. Zip the contents of the directory into a zip file.
```bash
       zip -r ingest_fsx_audit_logs.zip .
```
2. Create the Lambda function with:
    a. Python 3.10, or higher, as the runtime.
    b. Set the permissions to the role created above.
    c. Under "Additional Configurations" select "Enable VPC" and select a VPC and Subnet that will have access to all the FSxN cluster management endpoints that you want to gather audit logs from.
    d. Click `Create Function` and on the next page, under the “Code” tab, select "Upload From -> .zip file." Provide the .zip file created by the steps above. 
    e. From the Configuration -> General tab set the timeout to at least 30 seconds. You will may need to increase that if it has to process a lot of audit entries and/or process a lot of FSxN file systems.
3. Configure the Lambda function by setting the following environment variables. For a Lambda function you do this by clicking on the `Configuration` tab and then the `Environment variables` section.

| Variable | Description |
| --- | --- |
| secretArn | The ARN of the secret that contains the credentials to access the FSx for Data ONTAP file system. |
| secretRegion | The region where the secret is stored. |
| s3BucketRegion | The region of the S3 bucket where stats file is stored. |
| s3BucketName | The name of the S3 bucket where the stats are stored. |
| statsName | The name of the S3 object that contains the stats file. |
| logGroupName | The name of the CloudWatch log group to ingest the audit logs into. |

4. After you have tested it, add an EventBridge trigger to run periodically. You can do this by clicking on the `Add Trigger` button and selecting `EventBridge (CloudWatch Events)` from the dropdown. You can then configure the schedule to run as often as you want. How often depends on how often you have set up your FSx for ONTAP file systems to generate audit logs, and how up-to-date you want the CloudWatch logs to be.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
