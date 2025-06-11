# :warning: **NOTICE:**

Continuous development for this solution has moved to a separate GitHub repository found here
[https://github.com/NetApp/FSx-ONTAP-monitoring/tree/main/FSx_Alerting/Auto-Add-CloudWatch-Alarms](https://github.com/NetApp/FSx-ONTAP-monitoring/tree/main/FSx_Alerting/Auto-Add-CloudWatch-Alarms).
Please refer to that repository for the latest updates.

# Automatically Add Cloud Watch Alarms to Monitor Aggregate, Volume and CPU Utilization

## Introduction
There are times when you want to be notified when a FSx for ONTAP file system, or one of its volumes, is reaching
its capacity. AWS CloudWatch has metrics that can give you this information. The only problem is that they are
on a per instance basis. This means as you add and delete file systems and/or volumes, you have to add and
delete alarms. This can be tedious, and error prone. This script will automate the creation of
AWS CloudWatch alarms that monitor the utilization of the file system and its volumes. It will also create alarms
to monitor the CPU utilization of the file system. And if a volume or file system is removed, it will remove the associated alarms.

To implement this, you might think to just create EventBridge rules that trigger on the creation or deletion of an FSx Volume.
This would kind of work, but since you have command line access to the FSx for ONTAP file system, you can create
and delete volumes without generating any CloudTrail events. So, depending on CloudTrail events would not be reliable. Therefore, instead
of relying on those events, this script will scan all the file systems and volumes in all the regions then create and delete alarms as needed.

## Invocation
The preferred way to run this script is as a Lambda function. That is because it is very inexpensive to run without having
to maintain any compute resources. You can use an `EventBridge Schedule` to run it on a regular basis to
ensure that all the CloudWatch alarms are kept up to date. Since there are several steps involved in setting up a Lambda function,
a CloudFormation template is included in the repo, named `cloudlformation.yaml`, that will do the following steps for you:
- Create a role that will allow the Lambda function to:
    - List AWS regions. This is so it can get a list of all the regions, so it can know which regions to scan for FSx for ONTAP file systems and volumes.
    - List the FSx for ONTAP file systems.
    - List the FSx volumes.
    - List the CloudWatch alarms.
    - List tags for the resources. This is so you can customize the thresholds for the alarms on a per instance basis. More on that below.
    - Create CloudWatch alarms.
    - Delete CloudWatch alarms that it has created (based on alarm names).
- Create a Lambda function with the Python program.
- Create an EventBridge schedule that will run the Lambda function on a user defined basis.
- Create a role that will allow the EventBridge schedule to trigger the Lambda function.

To use the CloudFormation template perform the following steps:

1. Download the `cloudformation.yaml` file from this repo.
2. Go to the `CloudFormation` services page in the AWS console and select `Create Stack -> With new resources (standard)`.
3. Select `Choose an existing template` and `Upload a template file`.
4. Click `Choose file` and select the `cloudformation.yaml` file you downloaded in step 1.
5. Click `Next` and fill in the parameters presented on the next page. The parameters are:
    - `Stack name` - The name of the CloudFormation stack. Note this name is also used as a base name for some of the resources that are created, to make them unique, so you must keep this string under 25 characters, so the resource names don't exceed their name length limit.
    - `SNStopic` - The SNS Topic name where CloudWatch will send alerts to. Note that since CloudWatch can't send messages to an SNS topic residing in a different region, it is assumed that the SNS topic, with the same name, will exist in all the regions where alarms are to be created.
    - `accountId` - The AWS account ID associated with the SNS topic. This is only used to compute the ARN to the SNS Topic set above.
    - `customerId` - This is optional. If provided the string entered is included in the description of every alarm created.
    - `defaultCPUThreshold` - This will define a default CPU utilization threshold. You can override the default by having a specific tag associated with the file system (see below for more information).
    - `defaultSSDThreshold` - This will define a default SSD (aggregate) utilization threshold. You can override the default by having a specific tag associated with the file system (see below for more information).
    - `defaultVolumeThreshold` - This will define the default Volume utilization threshold. You can override the default by having a specific tag associated with the volume (see below for more information).
    - `checkInterval` - This is the interval in minutes that the program will run.
    - `alarmPrefixString` - This defines the string that will be prepended to every CloudWatch alarm name that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.
    - `regions` - This is a comma separated list of AWS region names (e.g. us-east-1) that the program will act on. If not specified, the program will scan on all regions that support an FSx for ONTAP file system. Note that no checking is performed to ensure that the regions you provide are valid.
6. Click `Next`. There aren't any recommended changes to make to any of the proceeding pages, so just click `Next` again.
7. On the final page, check the box that says `I acknowledge that AWS CloudFormation might create IAM resources with custom names.` and then click `Submit`.

If you prefer, you can run this Python program on any UNIX based computer that has Python installed. See the "Running on a computer" section below for more information.

### Configuring the program
If you use the CloudFormation template to deploy the program, it will create the appropriate environment variables for you.
However, if you didn't use the CloudFormation template, you will need to configure the program yourself. Here are the
various ways you can do so:
* By editing the top part of the program itself where there are the following variable definitions.
* By setting environment variables with the same names as the variables in the program.
* If running it as a standalone program, via some command line options.

:bulb: **NOTE:** The CloudFormation template will prompt for these values when you create the stack and will set the appropriate environment variables for you.

Here is the list of variables, and what they define:

| Variable | Description |Command Line Option|
|:---------|:------------|:--------------------------------|
|SNStopic  | The SNS Topic name where CloudWatch will send alerts to. Note that it is assumed that the SNS topic, with the same name, will exist in all the regions where alarms are to be created.|-s SNS\_Topic\_Name|
|accountId | The AWS account ID associated with the SNS topic. This is only used to compute the ARN to the SNS Topic.|-a Account\_number|
|customerId| This is just an optional string that will be added to the alarm description.|-c Customer\_String|
|defaultCPUThreshold | This will define the default CPU utilization threshold. You can override the default by having a specific tag associated with the file system. See below for more information.|-C number|
|defaultSSDThreshold | This will define the default SSD (aggregate) utilization threshold. You can override the default by having a specific tag associated with the file system. See below for more information.|-S number|
|defaultVolumeThreshold | This will define the default Volume utilization threshold. You can override the default by having a specific tag associated with the volume. See below for more information.|-V number|
|alarmPrefixCPU | This defines the string that will be put in front of the name of every CPU utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|
|alarmPrefixSSD | This defines the string that will be put in front of the name of every SSD utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|
|alarmPrefixVolume | This defines the string that will be put in front of the name of every volume utilization CloudWatch alarm that the program creates. Having a known prefix is how it knows it is the one maintaining the alarm.|N/A|
|regions   | This is a comma separated list of AWS region names (e.g. us-east-1) that the program will act on. If not specified, the program will scan on all regions that support an FSx for ONTAP file system. Note that no checking is performed to ensure that the regions you provide are valid.|-r region -r region ...|

There are a few command line options that don't have a corresponding variable:
|Option|Description|
|:-----|:----------|
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
having to edit the program, you can either use the Command Line Option specified in the table above or you can
set the appropriate environment variable. Note that you can give a `-h` (or `--help`) command line option
and the program will display a list of all the available options.

You can limit the regions that the program will act on by using the `-r region` option. You can specify that option
multiple times to act on multiple regions.

You can run the program in "Dry Run" mode by specifying the `-d` (or `--dryRun`) option. This will cause the program to only display
messages showing what it would have done, and not really create or delete any CloudWatch alarms.

### Running as a Lambda function
A CloudFormation template is included in the repo that will do the steps below. If you don't want to use that, here are
the detailed steps required to install the program as a Lambda function.

#### Create a Lambda function
1. Download the `auto_add_cw_alarms.py` file from this repo.
2. Create a new Lambda function in the AWS console by going to the Lambda services page and clicking on the `Create function` button.
3. Choose `Author from scratch` and give the function a name. For example `auto_add_cw_alarms`.
4. Choose the latest version of Python (currently Python 3.11) as the runtime and click on `Create function`.
5. In the function code section, copy and paste the contents of the `auto_add_cw_alarms.py` file into the code editor.
6. Click on the `Deploy` button to save the function.
7. Click on the Configuration tag and then the "General configuration" sub tab and set the "Timeout" to be at least 3 minutes.
8. Click on the "Environment variables" tab and add the following environment variables:
    - `SNStopic` - The SNS Topic name where CloudWatch will send alerts to.
    - `accountId` - The AWS account ID associated with the SNS topic.
    - `customerId` - This is optional. If provided the string entered is included in the description of every alarm created.
    - `defaultCPUThreshold` - This will define a default CPU utilization threshold.
    - `defaultSSDThreshold` - This will define a default SSD (aggregate) utilization threshold.
    - `defaultVolumeThreshold` - This will define the default Volume utilization threshold.
    - `alarmPrefixString` - This defines the string that will be prepended to every CloudWatch alarm name that the program creates.
    - `regions` - This is an optional comma separated list of AWS region names (e.g. us-east-1) that the program will act on. If not specified, the program will scan on all regions that support an FSx for ONTAP file system.

You will also need to set up the appropriate permissions for the Lambda function to run. It doesn't need many permissions. It just needs to be able to:
* List the FSx for ONTAP file systems.
* List the FSx volume names.
* List tags associated with an FSx file system or volume.
* List the CloudWatch alarms.
* List all the AWS regions.
* Create CloudWatch alarms.
* Delete CloudWatch alarms. You can set resource to `arn:aws:cloudwatch:*:`*AccountId*`:alarm:`*alarmPrefixString*`*` to limit the deletion to only the alarms that it creates.
* Create CloudWatch Log Groups and Log Streams in case you need to diagnose an issue.

The following is an example AWS policy that has all the required permissions to run the script (although you could narrow the "Resource" specification to suit your needs.)
Note it assumes that the alarmPrefixString is set to "FSx-ONTAP-Auto".
```JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "fsx:DescribeFilesystems",
                "fsx:DescribeVolumes",
                "fsx:ListTagsForResource",
                "cloudwatch:DescribeAlarms"
                "cloudwatch:DescribeAlarmsForMetric",
                "ec2:DescribeRegions",
                "cloudwatch:PutMetricAlarm",
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

Once you have deployed the Lambda function it is recommended to set up a schedule to run it on a regular basis.
The easiest way to do that is:
1. Click on the `Add trigger` button from the Lambda function page.
2. Select `EventBridge (CloudWatch Events)` as the trigger type.
3. Click on the `Create a new rule` button.
4. Give the rule a name and a description.
5. Set the `Schedule expression` to be the interval you want the function to run. For example, if you want it to run every 15 minutes, you would set the expression to `rate(15 minutes)`.
6. Click on the `Add` button

### Expected Action
Once the script has been configured and invoked, it will:
* Scan for every FSx for ONTAP file systems in every region, unless you have specified a specific list of regions to scan. For every file system that it finds it will:
    * Create a CPU utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
    * Create an SSD utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
* Scan for every FSx for ONTAP volume in every region, unless you have specified a specific list of regions to scan. For every volume it finds it will:
    * Create a Volume Utilization CloudWatch alarm, unless the threshold value is set to 100 for the specific alarm.
* Scan for the CloudWatch alarms and remove any alarms that the associated resource doesn't exist anymore.

### Cleaning up
If you decide you don't want to use this program anymore, you can delete the CloudFormation stack that you created.
This will remove the Lambda function, the EventBridge schedule, and the roles that were created for you. If you did
not use the CloudFormation template, you will have to do these steps yourself.

Once you have removed the program, you can remove all the CloudWatch alarms that were created by the program by running
the following command:

```bash
region=us-west-2
aws cloudwatch describe-alarms --region=$region --alarm-name-prefix "FSx-ONTAP-Auto" --query "MetricAlarms[*].AlarmName" --output text | xargs -n 50 aws cloudwatch delete-alarms --region $region --alarm-names
```
This command will remove all the alarms that have an alarm name that starts with "FSx-ONTAP-Auto" in the us-west-2 region.
Make sure to adjust the alarm-name-prefix to match the AlarmPrefix you set when you deployed the program.
You will also need to adjust the region variable and run the `aws` command again for each region where you have alarms in.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
