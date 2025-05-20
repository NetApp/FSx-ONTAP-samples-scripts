# Monitoring ONTAP Services

## Introduction
This program is used to monitor various services of an AWS FSx for NetApp ONTAP file system and alert you if anything
is outside of the specified conditions. It uses the ONTAP APIs to obtain the required information to
determine if any of the conditions that are being monitored have been met.
If they have, then the program will send an SNS message to the specified SNS topic. The program can also send
a syslog message to a syslog server as well as store the event information into a CloudWatch Log Stream.
The program will store the event information in an S3 bucket so that it can be compared against to ensure
it doesn't send multiple messages for the same event. You can configure the program either via environment variables
or via a configuration file. The configuration file is kept in the S3 bucket for easy access.

Here is an itemized list of the services that this program can monitor:
- If the file system is available.
- If the underlying Data ONTAP version has changed.
- If the file system is running off its partner node (i.e. is running in failover mode).
- If any of the network interfaces are down.
- Any EMS message. Filtering is provided to allow you to only be alerted on the EMS messages you care about.
- If any of the vservers are down.
- If any of the protocol (NFS & CIFS) servers within a vserver are down.
- If a SnapMirror relationship hasn't been updated within either a specified amount of time or as a percentage of time since its last scheduled update.
- If a SnapMirror update has stalled.
- If a SnapMirror relationship is in a "non-healthy" state.
- If the aggregate is over a certain percentage full. You can set two thresholds (Warning and Critical).
- If a volume is over a certain percentage full. You can set two thresholds (Warning and Critical).
- If a volume is using more than a specified percentage of its inodes. You can set two thresholds (Warning and Critical).
- If a volume if offline.
- If any quotas are over a certain percentage full. You can be alerted on both soft and hard limits.

## Architecture
The program is designed to be run as a Lambda function but can be run as a standalone program.
As a Lambda function it can be set up to run on a regular basis by creating an EventBridge schedule.
Once the program has been invoked it will use the ONTAP APIs to obtain the required information 
from the ONTAP system. It will compare this information against the conditions that have been
specified in the conditions files. If they have, then the program will send an SNS message
to the specified SNS topic and optionally, send a syslog message as well as put an event
into a CloudWatch log group. The program stores event information in an S3 bucket so it can ensure that it doesn't
send duplicate messages for the same event. The configuration file is also kept in the S3 bucket for easy access.

Since the program must be able to communicate with the FSxN file system management endpoint, it must
run within a VPC that has connectivity to the FSxN file system. This requires special considerations for
a Lambda function, both how it is deployed, and how it is able to access AWS services. You can read more about
that in the [Endpoints for AWS Services](#endpoints-for-aws-services) section below.

![Architecture](images/Monitoring_ONTAP_Services_Architecture-2.png)

## Prerequisites
- An FSx for NetApp ONTAP file system you want to monitor.
- An S3 bucket to store the configuration and event status files, as well as the Lambda layer zip file.
    - You will need to download the [Lambda layer zip file](https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/monitor-ontap-services/lambda_layer.zip) from this repo and upload it to the S3 bucket. Be sure to preserve the name `lambda_layer.zip`.
- The security group associated with the FSx for ONTAP file system must allow inbound traffic from the Lambda function over TCP port 443.
- An SNS topic to send the alerts to.
- An AWS Secrets Manager secret that holds the FSx for ONTAP file system credentials. There should be two keys in the secret, one for the username and one for the password.
- Optionally:
    - A CloudWatch Log Group to store events.
    - A syslog server to receive event messages.

## Installation
There are two ways to install this program. You can either perform all the steps shown in the
[Manual Installation](#manual-installation) section below, or run the [CloudFormation template](cloudformation.yaml)
that is provided in this repository. The manual installation is more involved, but it gives you
more control and allows you to make changes to settings that aren't available through the CloudFormation template.
The CloudFormation template is easier to use, but it doesn't allow for as much customization.

### Installation using the CloudFormation template
The CloudFormation template will do the following:
- Create a role for the Lambda function to use. The permissions will be the same as what
    is outlined in the [Create an AWS Role](#create-an-aws-role) section below.
    **NOTE:** You can provide the ARN of an existing role to use instead of having it create a new one.
- Create a role that allows the EventBridge schedule to trigger the Lambda function.
    The only permission that this role needs is to be able to invoke a Lambda function.
    **NOTE:** You can provide the ARN of an existing role to use instead of having it create a new one.
- Create the Lambda function with the Python code provided in this repository.
- Create an EventBridge Schedule to trigger the Lambda function. By default, it will trigger
    it to run every 15 minutes, although there is a parameter that will allow you to set it to whatever interval you want.
- Optionally create a CloudWatch alarm that will alert you if the Lambda function fails.
    - Create a Lambda function to send the CloudWatch alarm alert to an SNS topic. This is done so the SNS topic can be in another region since CloudWatch doesn't support doing that natively.
- Optionally create a VPC Endpoints for the SNS, Secrets Manager, CloudWatch and/or S3 AWS services.

To install the program using the CloudFormation template, you will need to do the following:
1. Download the CloudFormation template from this repository. You can do that by clicking on
    the [cloudformation.yaml](./cloudformation.yaml) file in the repository, then clicking on
    the download icon next to the "Raw" button at the top right of the page. That should
    cause your browser to download the file to your local computer.
2. Go to the [CloudFormation service in the AWS console](https://us-west-2.console.aws.amazon.com/cloudformation/) and click on "Create stack (with new resources)".
3. Choose the "Upload a template file" option and select the CloudFormation template you downloaded in step 1.
4. This should bring up a new window with several parameters to provide values to. Most have
    defaults, but some do require values to be provided. See the list below for what each parameter is for.

|Parameter Name | Notes|
|---|---|
|Stackname|The name you want to assign to the CloudFormation stack. Note that this name is used as a base name for some of the resources it creates, so please keep it **under 25 characters**.|
|OntapAdminServer|The DNS name, or IP address, of the management endpoint of the FSxN file system you wish to monitor.|
|S3BucketName|The name of the S3 bucket where you want the program to store event information. It should also have a copy of the `lambda_layer.zip` file. **NOTE** This bucket must be in the same region where this CloudFormation stack is being created.|
|SubnetIds|The subnet IDs that the Lambda function will be attached to. They must have connectivity to the FSxN file system management endpoint that you wish to monitor. It is recommended to select at least two.|
|SecurityGroupIds|The security group IDs that the Lambda function will be attached to. The security group must allow outbound traffic over port 443 to the SNS, Secrets Manager, and CloudWatch and S3 AWS service endpoints, as well as the FSxN file system you want to monitor.|
|SnsTopicArn|The ARN of the SNS topic you want the program to publish alert messages to.|
|CloudWatchLogGroupName|The name of **an existing** CloudWatch Log Group that the Lambda function can send event messages to. It will create a new Log Stream within the Log Group every day that is unique to this file system so you can use the same Log Group for multiple instances of this program. If this field is left blank, alerts will not be sent to CloudWatch.|
|SecretArn|The ARN of the secret within the AWS Secrets Manager that holds the FSxN file system credentials.|
|SecretUsernameKey|The name of the key within the secret that holds the username portion of the FSxN file system credentials. The default is 'username'.|
|SecretPasswordKey|The name of the key within the secret that holds the password portion of the FSxN file system credentials. The default is 'password'.|
|CheckInterval|The interval, in minutes, that the EventBridge schedule will trigger the Lambda function. The default is 15 minutes.|
|CreateCloudWatchAlarm|Set to "true" if you want to create a CloudWatch alarm, and accompanying Lambda function, that will alert you if the monitoring Lambda function fails.|
|CreateSecretsManagerEndpoint|Set to "true" if you want to create a Secrets Manager endpoint. **NOTE:** If a SecretsManager Endpoint already exist for the specified Subnet the endpoint creation will fail, causing the entire CloudFormation stack to fail. Please read the [Endpoints for AWS services](#endpoints-for-aws-services) for more information.|
|CreateSNSEndpoint|Set to "true" if you want to create an SNS endpoint. **NOTE:** If a SNS Endpoint already exist for the specified Subnet the endpoint creation will fail, causing the entire CloudFormation stack to fail. Please read the [Endpoints for AWS services](#endpoints-for-aws-services) for more information.|
|CreateCWEndpoint|Set to "true" if you want to create a CloudWatch endpoint. **NOTE:** If a CloudWatch Endpoint already exist for the specified Subnet the endpoint creation will fail, causing the entire CloudFormation stack to fail. Please read the [Endpoints for AWS services](#endpoints-for-aws-services) for more information.|
|CreateS3Endpoint|Set to "true" if you want to create an S3 endpoint. **NOTE:** If a S3 Gateway Endpoint already exist for the specified VPC the endpoint creation will fail, causing the entire CloudFormation stack to fail. Note that this will be a "Gateway" type endpoint, since they are free to use. Please read the [Endpoints for AWS services](#endpoints-for-aws-services) for more information.|
|RoutetableIds|The route table IDs to update to use the S3 endpoint. Since the S3 endpoint is of type `Gateway` route tables have to be updated to use it. This parameter is only needed if you are creating an S3 endpoint.|
|VpcId|The ID of a VPC where the subnets provided above are located. Required if you are creating an endpoint, not needed otherwise.|
|EndpointSecurityGroupIds|The security group IDs that the endpoint will be attached to. The security group must allow traffic over TCP port 443 from the Lambda function. This is required if you are creating an Lambda, CloudWatch or SecretsManager endpoint.|
|LambdaRoleArn|The ARN of the role that the Lambda function will use. This role must have the permissions listed in the [Create an AWS Role](#create-an-aws-role) section below. If left blank a role will be created for you.|
|SchedulerRoleArn|The ARN of the role that the EventBridge schedule will use to trigger the Lambda function. It just needs the permission to invoke a Lambda function. If left blank a role will be created for you.|
|watchdogRoleArn|The ARN of the role that the Lambda function that the Watchdog CloudWatch alert will use to send SNS alerts if something goes wrong with the monitoring Lambda function. The only required permission is to publish to the SNS topic listed above, although highly recommended that you also add the AWS managed "AWSLambdaBasicExecutionRole" policy that allows the Lambda function to create and write to a CloudWatch log stream so it can provide diagnostic output of something goes wrong. Only required if creating a CloudWatch alert and you want to provide your own role. If left blank a role will be created for you if needed.|

The remaining parameters are used to create the matching conditions configuration file, which specify when the program will send an alert.
You can read more about it in the [Matching Conditions File](#matching-conditions-file) section below. All these parameters have reasonable default values
so you probably won't have to change any of them. Note that if you enable EMS alerts, then the default rule will
alert on all EMS messages that have a severity of `Error`, `Alert` or `Emergency`. You can change the
matching conditions at any time by updating the matching conditions file that is created in the S3 bucket.
The name of the file will be `<OntapAdminServer>-conditions` where `<OntapAdminServer>` is the value you
set for the OntapAdminServer parameter.

### Post Installation Checks
After the stack has been created, check the status of the Lambda function to make sure it is
not in an error state. To find the Lambda function go to the Resources tab of the CloudFormation
stack and click on the "Physical ID" of the Lambda function. This should bring you to the Lambda service in the AWS
console. Once there, click on the "Monitor" tab to see if the function has been invoked. Locate the
"Error count and success rate(%)" chart, which is usually found at the top right corner of the "Monitor" dashboard.
Within the "CheckInterval" number of minutes there should be at least one dot on that chart. Note that initially
the chart is slow to reflect any status so you might have to be patient. Continue to press the "refresh"
button (the icon with a circle on it) every minute or so to update the status. Once you see a dot on the chart, when you hover your mouse
over it, you should see the "success rate" and "number of errors." The success rate should be 100% and the number
of errors should be 0. If it is not, then scroll down to the CloudWatch Logs section and click on the most recent
log stream. This will show you the output of the Lambda function. If there are any errors, they will be displayed
there. If you can't figure out what is causing an error, then please create an issue in this repository and someone
will help you.

---

### Manual Installation
If you want more control over the installation then you can install it manually by following the steps below. Note that these
instructions assume you have familiarity with how to create the various AWS service mentioned below. If you do not,
the recommended course of action is to use the CloudFormation method of deploying the program. Then, if you need to change things, 
you can make the required modifications using the information found below.

#### Create an AWS Role
This program doesn't need many AWS permissions. It just needs to be able to read the FSxN file system credentials stored in a Secrets Manager secret,
read and write objects in an s3 bucket, be able to publish SNS messages, and optionally create CloudWatch log Streams and put events.
Below is the specific list of permissions needed.

| Permission                    | Reason     |
|:------------------------------|:----------------|
|secretsmanager:GetSecretValue  | To be able to retrieve the FSxN administrator credentials.|
|sns:Publish                    | To allow it to send messages (alerts) via SNS.|
|s3:PutObject                   | So it can store its state information in various s3 objects.|
|s3:GetObject                   | So it can retrieve previous state information, as well as configuration files, from various s3 objects. |
|s3:ListBucket                  | So it can detect if an object exist or not. |
|logs:CreateLogStream           | If you want the program to send its logs to CloudWatch, it needs to be able to create a log stream. |
|logs:PutLogEvents              | If you want the program to send its logs to CloudWatch, it needs to be able to put log events into the log stream. |
|logs:DescribeLogStreams        | If you want the program to send its logs to CloudWatch, it needs to be able to see if a log stream already exists before attempting to send events to it. |
|ec2:CreateNetworkInterface     | Since the program runs as a Lambda function within your VPC, it needs to be able to create a network interface in your VPC. You can read more about that [here](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html). |
|ec2:DeleteNetworkInterface     | Since it created a network interface, it needs to be able to delete it when not needed anymore. |
|ec2:DescribeNetworkInterfaces  | So it can check to see if a network interface already exists. |

#### Create an S3 Bucket
The first use of the s3 bucket will be to store the Lambda layer zip file. This is required to include some dependencies that
aren't included in the AWS Lambda environment. Currently the only dependency in the zip file is [cronsim](https://pypi.org/project/cronsim/).
This is used to interpret the SnapMirror schedules to be able to report on lag issues. You can download the zip file from this repository by clicking on
the [lambda_layer.zip](https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/monitor-ontap-services/lambda_layer.zip) link.
You will refer to this file, and bucket, when you create the Lambda function.

Another use of the s3 bucket is to store events that have already reported on so they can be compared against
to ensure program does not send multiple messages for the same event.
Note that it doesn't keep every event indefinitely, it only stores them while the condition is true. So, say for
example it sends an alert for a SnapMirror relationship that has a lag time that is too long. It will
send the alert and store the event. Once a successful SnapMirror synchronization has happened, the event will be removed
from the s3 object allowing for a new event to be created and alerted on. If you want to keep the event information
longer than that, please configure the program to store them in a CloudWatch log group.

So, for the program to function, you will need to provide an S3 bucket for it to store event history. It is recommended to
have a separate bucket for each deployment of this program. However, that isn't required, since you can
specify the object names for the event file and therefore you could manually ensure that each instance of the Lambda function doesn't 
overwrite the event files of another instance.

This bucket is also used to store the Matching Condition file. You can read more about it in the [Matching Conditions File](#matching-conditions-file) below.

#### Create an SNS Topic
Since the way this program sends alerts is via an SNS topic, you need to either create SNS topic, or use an
existing one.

#### Create a Secrets Manager Secret
Since the program issues API calls to the FSxN file system, it needs to be able to authenticate itself to the FSxN file system.
The safest way to provide credentials to the program is to use the AWS Secrets Manager service. Therefore, a Secrets Manager
secret must be created that contains the FSxN file system credentials. The secret should contain two keys, one for the
username and one for the password.

The following command will create the secret for you. Just replace the values in the command with your own.

```bash
aws secretsmanager create-secret --name <SecretName> --secret-string '{"username":"<FSxN_Username>","password":"<FSxN_Password>"}'
```

#### Create a CloudWatch Log Group
If you want the program to send its logs to CloudWatch, you will need to create a CloudWatch Log Group for it to
send its logs to. The program will create a new log stream within the log group every day that is unique to the file system.
This step is optional if you don't want to send the logs to CloudWatch.

#### Endpoints for AWS Services
If you deploy this program as a Lambda function, you will have to run it within a VPC that has connectivity to the FSxN file
system that you want to monitor. The Lambda function will also need access to the AWS service endpoints for the AWS services
that it uses (S3, SNS, CloudWatch, and SecretsManager). Access to these service endpoints is typically routed through the Internet,
however, because of the way AWS gives Lambda access to your subnet, it will not be allowed access to the Internet through an Internet Gateway
but it will allow access to the Internet through a NAT Gateway. Therefore, in order to allow access to these service endpoints you'll need to do one of the following:
- Deploy the Lambda function in a subnet that does **not** have an Internet Gateway, yet does have access
    to the Internet via a NAT Gateway or through a Transit Gateway.
- Deploy AWS Service endpoint for each of the AWS services that the Lambda function uses.

If you do need to deploy AWS service endpoints, keep the following in mind:
- Since VPC endpoints can't traverse AWS regions, all AWS assets (e.g. FSx for ONTAP file system, SecretsManager Secret, S3 bucket,
    SNS Topic and CloudWatch Log Group) must be in the same region as the VPC endpoint.
- For interface type endpoints, a network interface will be created in the VPC's subnet to allow access.
  To transparently access the service via the VPC endpoint, AWS will update its
  DNS entry for the service endpoint to point to the IP address of the VPC interface endpoint. This is only
  done if the "Private DNS names" option is enabled for the endpoint and "DNS Hostnames" is enabled for the subnet.
  If those two options aren't possible, and/or you aren't using AWS's DNS resolver, then you can set the
  following configuration parameters to override the hostname that the program
  uses for the specified AWS service endpoints. You will want to set the parameter to the DNS hostname for the
  endpoint. It typically starts with 'vpce'.

    |Configuration Parameter|AWS Service Name|
    |---|---|
    |snsEndPointHostname|Simple Notification Service (SNS)|
    |secretsManagerEndPointHostname|Secrets Manager|
    |cloudWatchEndPointHostname|CloudWatch Logs|
- For the S3 service endpoint it is best to deploy a "Gateway" type endpoint, since they are free. For the other
  services they will have to be of type "interface."
    - In order for a gateway type service endpoint to be accessible, a route has to be created in the
      subnet's routing table.

**NOTE:** One indication that the Lambda function doesn't have access to an AWS service endpoint is if the Lambda function
times out, even after adjusting the timeout to more than several minutes.

#### Lambda Function
There are a few things you need to do to properly configure the Lambda function.
- Assign it the role you created above.
- Put it in a VPC and subnet that has access to the FSxN file system management endpoint.
- Assign it the security group that allows outbound traffic over TCP port 443 to the FSxN file system management endpoint.

Once you have created the function you will be able to:
- Copy the Python code from the [monitor_ontap_service.py](monitor_ontap_services.py)
    file found in this repository into the code box and deploy it.
- Add the Lambda layer to the function. You do this by first creating a Lambda layer then adding it to your function.
    To create a Lambda layer go to the Lambda service page on the AWS console and click on the "Layers"
    tab under the "Additional resources" section. Then, click on the "Create layer" button.
    From there you'll need to provide a name for the layer, and the path to the
    [lambda_layer.zip](https://raw.githubusercontent.com/NetApp/FSx-ONTAP-samples-scripts/main/Monitoring/monitor-ontap-services/lambda_layer.zip)
    file that you should download from this repository. If you uploaded that into the S3 bucket you created above, then
    just provide the S3 path to the file. For example, `s3://<your-bucket-name>.s3.<s3_region>.awsamzoneaws.com/lambda_layer.zip`.
    Once you have the layer created, you can add it to your Lambda function by going to the Lambda
    function in the AWS console, and clicking on the `Code` tab and scrolling down to the Layers section.
    Click on the "Add a layer" button. From there you can select the layer you just created.
- Increase the total run time to at least 20 seconds. You might have to raise that if you have a lot
    of components in your FSxN file system. However, if you have to raise it to more than a couple minutes
    and the function still times out, then it could be an issue with the endpoint causing the calls to the
    AWS services to hang. See the [Endpoints for AWS Services](#endpoints-for-aws-services) section above
    for more information.
- Provide for the base configuration via environment variables and/or a configuration file.
    See the [Configuration Parameters](#configuration-parameters) section below for more information.
- Create the "Matching Conditions" file, that specifies when the Lambda function should send alerts.
    See the [Matching Conditions File](#matching-conditions-file) section below for more information.
- Once you have tested the function to ensure it works, set up an EventBridge Schedule
    rule to trigger the function on a regular basis.

##### Configuration Parameters
Below is a list of parameters that are used to configure the program. Some parameters are required to be set
while others are optional. Some of the optional ones are still required to be set to something but
will have a usable default value if the parameter is not explicitly set. For the parameters that aren't required to be
set via an environment variable, they can be set by creating a "configuration file" and putting the assignments
in it. The assignments should be of the form "parameter=value". The default filename for the configuration
file is what you set the OntapAdminServer variable to plus the string "-config". If you want to use a different
filename, then set the configFilename environment variable to the name of your choosing.

**NOTE:** Parameter names are case sensitive. 

|Parameter Name | Required | Required as an Environment Variable | Default Value | Description |
|:--------------|:--------:|:-----------------------------------:|:--------------|:------------|
| s3BucketName   | Yes | Yes | None | Set to the name of the S3 bucket where you want the program to store events to. It will also read the matching configuration file from this bucket. |
| s3BucketRegion | Yes | Yes | None | Set to the region where the S3 bucket is located. |
| OntapAdminServer | Yes | Yes | None | Set to the DNS name, or IP address, of the ONTAP server you wish to monitor. |
| configFilename | No | No | OntapAdminServer + "-config" | Set to the filename (S3 object) that contains parameter assignments. It's okay if it doesn't exist, as long as there are environment variables for all the required parameters. |
| emsEventsFilename | No | No | OntapAdminServer + "-emsEvents" | Set to the filename (S3 object) where you want the program to store the EMS events that it has alerted on. This file will be created as necessary. |
| smEventsFilesname | No | No | OntapAdminServer + "-smEvents" | Set to the filename (S3 object) where you want the program to store the SnapMirror that it has alerted on. This file will be created as necessary.  |
| smRelationshipsFilename | No | No | OntapAdminServer + "-smRelationships" | Set to the filename (S3 object) where you want the program to store the SnapMirror relationships into. This file is used to track the number of bytes transferred so it can detect stalled SnapMirror updates. This file will be created as necessary. |
| storageEventsFilename | No | No | OntapAdminServer + "-storageEvents" | Set to the filename (S3 object) where you want the program to store the Storage Utilization events it has alerted on. This file will be created as necessary. |
| quotaEventsFilename | No | No | OntapAdminServer + "-quotaEvents" | Set to the filename (S3 object) where you want the program to store the Quota Utilization events it has alerted on. This file will be created as necessary. |
| vserverEventsFilename | No | No | OntapAdminServer + "-vserverEvents" | Set to the filename (S3 object) where you want the program to store the vserver events it has alerted on. This file will be created as necessary. |
| systemStatusFilename | No | No | OntapAdminServer + "-systemStatus" | Set to the filename (S3 object) where you want the program to store the overall system status information into. This file will be created as necessary. |
| snsTopicArn | Yes | No | None | Set to the ARN of the SNS topic you want the program to publish alert messages to. |
| cloudWatchLogGroupName | No | No | None | The name of **an existing** CloudWatch log group that the Lambda function will also send alerts to. If left blank, alerts will not be sent to CloudWatch.|
| conditionsFilename | Yes | No | OntapAdminServer + "-conditions" | Set to the filename (S3 object) where you want the program to read the matching condition information from. |
| secretArn | Yes | No | None | Set to the ARN of the secret within the AWS Secrets Manager that holds the FSxN credentials. |
| secretUsernameKey | Yes | No | None | Set to the key name within the AWS Secrets Manager secret that holds the username portion of the FSxN credentials. |
| secretPasswordKey | Yes | No | None | Set to the key name within the AWS Secrets Manager secret that holds the password portion of the FSxN credentials. |
| snsEndPointHostname | No | No | None | Set to the DNS hostname assigned to the SNS endpoint. Only needed if you had to create a VPC endpoint for the SNS service. | 
| secretsManagerEndPointHostname | No | No | None | Set to the DNS hostname assigned to the SecretsManager endpoint created above. Only needed if you had to create a VPC endpoint for the Secrets Manager service.|
| cloudWatchLogsEndPointHostname | No | No | None | Set to the DNS hostname assigned to the CloudWatch Logs endpoint created above. Only needed if you had to create a VPC endpoint for the Cloud Watch Logs service|
| syslogIP | No | No | None | Set to the IP address (or DNS hostname) of the syslog server where you want alerts sent to.|

##### Matching Conditions File
The Matching Conditions file allows you to specify which events you want to be alerted on. The format of the
file is JSON. JSON is basically a series of "key" : "value" pairs. Where the value can be object that also has
"key" : "value" pairs. For more information about the format of a JSON file, please refer to this [page](https://www.json.org/json-en.html).
The JSON schema in this file is made up of an array of objects, with a key name of "services". Each element of the "services" array
is an object with at least two keys. The first key is “name" which specifies the name of the service it is going to provide
matching conditions (rules) for. The second key is "rules" which is an array of objects that provide the specific
matching condition. Note that each service's rules has its own unique schema. The following is the definition of each service's schema.

###### Matching condition schema for System Health (systemHealth)
Each rule should be an object with one, or more, of the following keys:

|Key Name|Value Type|Notes|
|---|---|---|
|versionChange|Boolean (true, false)|If `true` the program will send an alert when the ONTAP version changes. If it is set to `false`, it will not report on version changes.|
|failover|Boolean|If 'true' the program will send an alert if the FSxN cluster is running on its standby node. If it is set to `false`, it will not report on failover status.|
|networkInterfaces|Boolean|If 'true' the program will send an alert if any of the network interfaces are down.  If it is set to `false`, it will not report on any network interfaces that are down.|

###### Matching condition schema for EMS Messages (ems)
Each rule should be an object with three keys, with an optional 4th key:

|Key Name|Value Type|Notes|
|---|---|---|
|name|String|Regular expression that will match on an EMS event name.|
|message|String|Regular expression that will match on an EMS event message text.|
|severity|String|Regular expression that will match on the severity of the EMS event (debug, informational, notice, error, alert or emergency).|
|filter|String|If any event's message text match this regular express, then the EMS event will be skipped. Try to be as specific as possible to avoid unintentional filtering. This key is optional.|

Note that all values to each of the keys are used as a regular expressions against the associated EMS component. For
example, if you want to match on any event message text that starts with “snapmirror” then you would put `^snapmirror`.
The `^` character matches the beginning on the string. If you want to match on a specific EMS event name, then you should
anchor it with a regular express that starts with `^` for the beginning of the string and ends with `$` for the end of
the string. For example, `^arw.volume.state$`.  For a complete explanation of the regular expression syntax and special
characters, please refer to the [Python documentation](https://docs.python.org/3/library/re.html).

###### Matching condition schema for SnapMirror relationships (snapmirror)
Each rule should be an object with one, or more, of the following keys:

|Key Name|Value Type|Notes|
|---|---|---|
|maxLagTime|Integer|Specifies the maximum allowable time, in seconds, since the last successful SnapMirror update before an alert will be sent. Only used if maxLagTimePercent hasn't been provide, or if the SnapMirror relationship, and the policy it is assigned to, don't have a schedule associated with them. Best practice is to provide both maxLagTime and maxLagTimePercent to ensure all relationships get monitored, in case a schedule gets accidentally removed.|
|maxLagTimePercent|Integer|Specifies the maximum allowable time, in terms of percent of the amount of time since the last scheduled SnapMirror update, before an alert will be sent. Should be over 100. For example, a value of 200 means 2 times the period since the last scheduled update and if that was supposed to have happen 1 hour ago, it would alert if the relationship hasn't been updated within 2 hours.|
|stalledTransferSeconds|Integer|Specifies the minimum number of seconds that have to transpire before a SnapMirror transfer will be considered stalled.|
|healthy|Boolean|If `true` will alert with the relationship is healthy. If `false` will alert with the relationship is unhealthy.|

###### Matching condition schema for Storage Utilization (storage)
Each rule should be an object with one, or more, of the following keys:
|Key Name|Value Type|Notes|
|---|---|---|
|aggrWarnPercentUsed|Integer|Specifies the maximum allowable physical storage (aggregate) utilization (between 0 and 100) before an alert is sent.|
|aggrCriticalPercentUsed|Integer|Specifies the maximum allowable physical storage (aggregate) utilization (between 0 and 100) before an alert is sent.|
|volumeWarnPercentUsed|Integer|Specifies the maximum allowable volume utilization (between 0 and 100) before an alert is sent.|
|volumeCriticalPercentUsed|Integer|Specifies the maximum allowable volume utilization (between 0 and 100) before an alert is sent.|
|volumeWarnFilesPercentUsed|Integer|Specifies the maximum allowable volume files (inodes) utilization (between 0 and 100) before an alert is sent.|
|volumeCriticalFilesPercentUsed|Integer|Specifies the maximum allowable volume files (inodes) utilization (between 0 and 100) before an alert is sent.|
|offline:|Boolean|If `true` will alert if the volume is offline.|

###### Matching condition schema for Quota (quota)
Each rule should be an object with one, or more, of the following keys:

|Key Name|Value Type|Notes|
|---|---|---|
|maxHardQuotaSpacePercentUsed|Integer|Specifies the maximum allowable storage utilization (between 0 and 100) against the hard quota limit before an alert is sent.|
|maxSoftQuotaSpacePercentUsed|Integer|Specifies the maximum allowable storage utilization (between 0 and 100) against the soft quota limit before an alert is sent.|
|maxQuotaInodesPercentUsed|Integer|Specifies the maximum allowable inode utilization (between 0 and 100) before an alert is sent.|

###### Matching condition schema for Vserver (vserver)
Each rule should be an object with one, or more, of the following keys:
|Key Name|Value Type|Notes|
|---|---|---|
|vserverState|Boolean|If `true` will alert if the vserver is not in `running` state.|
|nfsProtocolState|Boolean|If `true` will alert if the NFS protocol is not enabled on a vserver.|
|cifsProtocolState|Boolean|If `true` will alert if the CIFS protocol is enabled for a vserver but doesn't have an `online` status.|

###### Example Matching conditions file:
```json
{
  "services": [
    {
      "name": "systemHealth",
      "rules": [
        {
          "versionChange": true,
          "failover": true
        },
        {
          "networkInterfaces": true
        }
      ]
    },
    {
      "name": "ems",
      "rules": [
        {
          "name": "^passwd.changed$",
          "severity": "",
          "message": ""
        },
        {
          "name": "",
          "severity": "alert|emergency",
          "message": ""
        }
      ]
    },
    {
      "name": "snapmirror",
      "rules": [
        {
          "maxLagTime": 86400
          "maxLagTimePercent": 200
        },
        {
          "healthy": false
        },
        {
          "stalledTransferSeconds": 600
        }
      ]
    },
    {
      "name": "storage",
      "exceptions": [{"svm": "fsx", "name": "fsx_root"}],
      "rules": [
        {
          "aggrWarnPercentUsed": 80,
          "aggrCriticalPercentUsed": 95
        },
        {
          "volumeWarnPercentUsed": 85,
          "volumeCriticalPercentUsed": 90
        },
        {
          "volumeWarnFilesPercentUsed": 85,
          "volumeCriticalFilesPercentUsed": 90
        }
      ]
    },
    {
      "name": "storage",
      "match": [{"svm": "fsx", "name": "fsx_root"}],
      "rules": [
        {
          "volumeWarnPercentUsed": 75,
          "volumeCriticalPercentUsed": 85
        },
        {
          "volumeWarnFilesPercentUsed": 80,
          "volumeCriticalFilesPercentUsed": 90
        }
      ]
    },
    {
      "name": "quota",
      "rules": [
        {
          "maxHardQuotaSpacePercentUsed": 95
        },
        {
          "maxSoftQuotaSpacePercentUsed": 100
        },
        {
          "maxQuotaInodesPercentUsed": 95
        }
      ]
    }
  ]
}
```
In the above example, it will alert on:

- Any version change, including patch level, of the ONTAP O/S.
- If the system is running off of the standby node.
- Any network interfaces that are down. 
- Any EMS message that has an event name of “passwd.changed”.
- Any EMS message that has a severity of "alert" or “emergency”.
- Any SnapMirror relationship with a lag time more than 200% the amount of time since its last scheduled update, if it has a schedule assoicated with it.
    Otherwise, if the last successful update has been more than 86400 seconds (24 hours).
- Any SnapMirror relationship with a lag time more than 86400 seconds (24 hours).
- Any SnapMirror relationship that has a non-healthy status.
- Any SnapMirror update that hasn't had any flow of data in 600 seconds (10 minutes).
- If the cluster aggregate is more than 80% full.
- If the cluster aggregate is more than 95% full.
- If any volume, except for the 'fsx_root' volume in the 'fsx' SVM, that is more than 85% full.
- if any volume, except for the 'fsx_root' volume in the 'fsx' SVM, that is more than 90% full.
- if any volume, except for the 'fsx_root' volume in the 'fsx' SVM, that is using more than 85% of its inodes.
- if any volume, except for the 'fsx_root' volume in the 'fsx' SVM, that is using more than 90% of its inodes.
- If for the 'fsx_root' volume in the 'fsx SVM, when it is more than 75% full.
- if for the 'fsx_root' volume in the 'fsx SVM, when it is more than 85% full.
- if for the 'fsx_root' volume in the 'fsx SVM, when it is using more than 80% of its inodes.
- if for the 'fsx_root' volume in the 'fsx SVM, when it is using more than 90% of its inodes.
- If any quota policies where the space utilization is more than 95% of the hard limit.
- If any quota policies where the space utilization is more than 100% of the soft limit.
- If any quota policies are showing any inode utilization more than 95%

A matching conditions file must be created and stored in the S3 bucket with the name given as the "conditionsFilename"
configuration variable. Feel free to use the example above as a starting point. Note that you should ensure it
is in valid JSON format, otherwise the program will fail to load the file. There are various programs and
websites that can validate a JSON file for you.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.
