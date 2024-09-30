# Automatically Add Cloud Watch Alarms to Monitor Aggregate, Volume and CPU Utilization

## Introduction
There are times when you want to be notified when a FSx for ONTAP file system, or one of its volumes, is reaching
its capacity. AWS CloudWatch has metrics that can give you this information. The only problem is that they are
on a per instance basis. This means as you add and delete file systems and/or volumes, you have to add and
delete alarms. This can be tedious, and error prone. This script will automate the creation of
AWS CloudWatch alarms that monitor the utilization of the file system and its volumes. It will also create alarms
to monitor the CPU utilization of the file system. And if a volume or file system is removed, it will remove the associated alarms.

To implement this, you might think to just create EventTail filters to trigger on the creation or deletion of an FSx Volume.
This would kind of work, but since you have command line access to the FSx for ONTAP file system, you can create
and delete volumes without generating any CloudTrail events. So, this method would not be reliable. Therefore, instead
of relying on those events, this script will scan all the file systems and volumes in all the regions then create and delete alarms as needed.

## Invocation
There are two ways you can invoke this script (Python program). Either from a computer that has Python installed, or you could install it
as a Lambda function. If you want to run it as a Lambda function, a CloudFormation template is included in the repo that will:
- Create a role that will allow the Lambda function to:
    - List AWS regions. This is so it can scan all regions for FSx for ONTAP file systems and volumes.
    - List the FSx for ONTAP file systems.
    - List the FSx volume.
    - List the CloudWatch alarms.
    - List tags for the resources. This is so you can customize the thresholds for the alarms.
    - Create CloudWatch alarms.
    - Delete CloudWatch alarms that it has created (based on alarm names).
- Create a Lambda function with the Python program.
- Create a EventBridge schedule that will run the Lambda function on a user defined basis.
- Create a role that will allow the EventBridge schedule to trigger the Lambda function.

### Configuring the program
Before you can run the program you will need to configure it. You can configure it a few ways:
* By editing the top part of the program itself where there are the following variable definitions.
* By setting environment variables with the same names as the variables in the program.
* If running it as a standalone program, via some command line options.

:bulb: **NOTE:** The CloudFormation template will prompt for these values when you create the stack and will set the appropriate environment variables for you.

Here is the list of variables, and what they define:

| Variable | Description |Command Line Option|
|:---------|:------------|:--------------------------------|
|SNStopic  | The SNS Topic name where CloudWatch will send alerts to. Note that it is assumed that the SNS topic, with the same name, will exist in all the regions where alarms are to be created.|-s SNS_Topic_Name|
|accountId | The AWS account ID associated with the SNStopic. This is only used to compute the ARN to the SNS Topic.|-a Account_number|
|customerId| This is really just a comment that will be added to the alarm description.|-c Customer_String|
|defaultCPUThreshold | This will define the default CPU utilization threshold. You can override the default by having a specific tag associated with the file system. See below for more information.|-C number|
|defaultSSDThreshold | This will define the default SSD (aggregate) utilization threshold. You can override the default by having a specific tag associated with the file system. See below for more information.|-S number|
|defaultVolumeThreshold | This will define the default Volume utilization threshold. You can override the default by having a specific tag associated with the volume. See below for more information.|-V number|
|alarmPrefixCPU    | This defines the string that will be put in front of the name of every CPU utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|
|alarmPrefixSSD    | This defines the string that will be put in front of the name of every SSD utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|
|alarmPrefixVolume | This defines the string that will be put in front of the name of every volume utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|

There are a few command line options that don't have a corresponding variables:
|Option|Description|
|:-----|:----------|
|-r region| This option can be specified multiple times to limit the regions that the program will act on. If not specified, the program will act on all regions.|
|-d| This option will cause the program to run in "Dry Run" mode. In this mode, the program will only display messages showing what it would have done, and not really create or delete any CloudWatch alarms.|
|-F filesystem\_ID| This option will cause the program to only add or remove alarms that are associated with the filesystem\_ID.|

As mentioned with the threshold variables, you can create a tag on the specific resource to override the default value set by the associated threshold
variable. Here is the list of tags and where they should be located:

|Tag|Description|Location|
|:---|:------|:---|
|alarm\_threshold | Sets the volume utilization threshold. | Volume |
|cpu\_alarm\_threshold| Sets the CPU utilization threshold. | File System |
|ssd\_alarm\_threshold| Sets the SSD utilization threshold. | File System |

:bulb: **NOTE:** When the alarm threshold is set to 100, the alarm will not be created. So, if you set the default to 100, then you can selectively add alarms by setting the appropriate tag.

### Running on a computer
To run the program on a computer, you must have Python installed. You will also need to install the boto3 library.
You can do that by running the following command:

```bash
pip install boto3
```
Once you have Python and boto3 installed, you can run the program by executing the following command:

```bash
python3 auto_add_cw_alarms.py
```
This will run the program based on all the variables set at the top. If you want to change the behavior without
having to edit the program, you can use the Command Line Option specified in the table above. Note that you can give a `-h` (or `--help`)
option and the program will display a list of all the available options.

You can limit the regions that the program will act on by using the `-r region` option. You can specify that option
multiple times to act on multiple regions.

You can run the program in "Dry Run" mode by specifying the `-d` (or `--dryRun`) option. This will cause the program to only display
messages showing what it would have done, and not really create or delete any CloudWatch alarms.

### Running as a Lambda function
A CloudFormation template is included in the repo that will do the steps below. Otherwise, here are the steps required to install the program as a Lambda function.

Create a Lambda function and upload the program as the function code. Set the timeout to at least five minutes since some of the API calls
can take a significant amount of "clock time" to run, especially in distant regions.

Once you have installed the Lambda function it is recommended to set up a scheduled type EventBridge rule so the function will run on a regular basis.

The appropriate permissions will need to be assigned to the Lambda function in order for it to run correctly.
It doesn't need many permissions. It just needs to be able to:
* List the FSx for ONTAP file systems.
* List the FSx volume names.
* List the CloudWatch alarms.
* Create CloudWatch alarms.
* Delete CloudWatch alarms. You can set resource to "arn:aws:cloudwatch:*:${AWS::AccountId}:alarm:FSx-ONTAP-Auto*" to limit the deletion to only the alarms that it created.
* Create CloudWatch Log Groups and Log Streams in case you need to diagnose an issue.

The following permissions are required to run the script (although you could narrow the "Resource" specification to suit your needs.)
```JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricAlarm",
                "fsx:ListTagsForResource",
                "fsx:DescribeVolumes",
                "fsx:DescribeFilesystems",
                "cloudwatch:DescribeAlarmsForMetric",
                "ec2:DescribeRegions",
                "cloudwatch:DescribeAlarms"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:DeleteAlarms"
            ],
            "Resource": "arn:aws:cloudwatch:*:*:alarm:FSx-ONTAP-Auto*"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:*:log-stream:*"
        },
        {
            "Sid": "VisualEditor3",
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:*:*:log-group:*"
        }
    ]
}
```

### Expected Action
Once the script has been configured and invoked, it will:
* Scan for every FSx for ONTAP file systems in every region. For every file system that it finds it will:
    * Create a CPU utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
    * Create an SSD utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
* Scan for every FSx for ONTAP volume in every region. For every volume it finds it will:
    * Create a Volume Utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
* Scan for the CloudWatch alarms and remove any alarms that the associated resource doesn't exist anymore.


## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
