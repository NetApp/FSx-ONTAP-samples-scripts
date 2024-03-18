# Introduction
Currently there is some functionality within an FSx for NetApp ONTAP file system for which there is no corresponding
CloudWatch metrics. For example, there is no CloudWatch metrics for a SnapMirror relationship, so there is no way to
alert on when an update has stalled, or it is simply not considered Healthy by Data ONTAP. The purpose of this blog
is to show how a relatively small Python program, that can be run as a Lambda function, can leverage the ONTAP APIs
to obtain the required information to detect certain conditions, and when found, send SNS messages to alert someone.

This program was initially created to forward EMS messages to an AWS service outside of the FSxN file system since
there was no way to do that from the FSxN file system itself (i.e. the syslog forwarding didn't work at the time). As it turns out this is
no longer the case, in that as of Data ONTAP 9.13.1 you can now forward EMS messages to a 'syslog' server. However, once this program was created,
other funtionality was added to monitor other Data ONTAP services that AWS didn't provide a way to trigger an alert when
something was outside of an expected realm. For example, if the lag time between SnapMirror synchroniation were more
than a specified amount of time. Or, if a SnapMirror update was stalled. This program can alert on all these things and more.
Here is an itemized list of the services that this program can monitor:
- If the file system is available.
- If the underlying Data ONTAP version has changed.
- If the file system is running off its partner node (i.e. a failover has occurred).
- Any EMS message, with filtering to allow you to only be alerted on the ones you care about.
- If a SnapMirror relationship hasn't been updated in a user specified amount of time.
- If a SnapMirror update has stalled.
- If a SnapMirror relationship is in a "non-healthy" state.
- If the aggregate is over a certain percentage full. User can set two thresholds (Warning and Critical).
- If a volume is over a certain percentage full. User can set two thresholds (Warning and Critical).
- If any quotas are over a certain percentage full. User can follow both soft and hard limits.

## Preparation
There are a few things you need to do to properly deploy this script.

### Create an AWS Role
This program doesn't need many permissions. It just needs to be able to read the ONTAP credentials stored in a Secrets Manager secret,
read and write objects in an s3 bucket, and be able to publish SNS messages. Below is the specific list of permissions
needed. The easiest way to give the Lambda function the permissions it needs is by creating a role with these 
permissions and assigning that role to the Lambda function.

| Permission                     | Reason     |
|:-----------------------------|:----------------|
|secretsmanager:GetSecretValue  | Needs to be able to retrieve the FSxN administrator credentials. |
|sns:Publish                    | Since it sends messages (alerts) via SNS, it needs to be able to do so. |
|s3:PutObjecct                  | The program stores its state information in various s3 objects.|
|s3:GetObject                   | The program reads previous state information, as well as configuration from various s3 objects. |
|s3:ListBucket                  | To allow the program to know if an object exist or not. |

### Create an S3 Bucket
One of the goals of the program is to not send multiple messages for the same event. It does this by storing the event
information in an s3 object so it can be compared against before sending a second message for the same event.
Note that it doesn't keep every event indefinitely, it only stores them while the condition is true. So, say for
example it sends an alert for a SnapMirror relationship that has a lag time that is too long. It will
send the alert and store the event. Once a successful SnapMirror synchronization has happen, the event will be removed
from the s3 object allowing for a new event to be created and alarmed on.

So, for the program to function, you will need to provide an S3 bucket for it to store event history. It is recommended to
have a separate bucket for each deployment of this function. However, that isn't required, since you can
specify the object names for the event file and therefore you could manually ensure that each instance of the Lambda function doesn't 
overwrite the event files of another instance.

### Create an SNS Topic
Since the way this program sends alerts is via an SNS topic, you need to either create SNS topic, or use an
existing one.

### Endpoints for AWS services
If you deploy this as a Lambda function, you will have to attach it to the VPC that your FSxN file system resides
in so it can run ONTAP APIs against it. When you do that, the Lambda function will not be able to access the
Internet, even if the subnet it is attached to can. Therefore, the Lambda function will require AWS Service Endpoints for
any service that it uses. In the case of this program, it needs an endpoint for the SNS, Secrets Manager and S3 services.
For the S3 service, it is best to deploy a "Gateway" type endpoint, since they are free. Unfortunately, you can't
deploy a Gateway type endpoint for the SNS and Secret Manager services, so those have to be "Interface" type. If
you don't setup the endpoints, the Lambda function will hang on the first AWS API call it tries to perform, which is typically calling the
Secrets Managers to obtain the credentials of the administrator account for the FSxN File System. So, if you
find that the Lambda function times out, even after adjusting the timeout to more than a minute, then chances
are this is your problem.

**NOTE:** The way the Lambda function is able to use the "local" (i.e. within the subnet) Interface endpoint, as
opposed to the Internet facing one, is usually from the DNS resolution of the endpoint hostname
"<AWS_Service_Name>.<Region>.amazonaws.com". In order for that to happen, you have to enable “Private DNS names”
for the endpoint. In order to do that, it is required to enable “DNS Hostnames” within the VPC settings. This VPC
setting is not enabled by default. After making these changes, if you are using Route53 as your DNS resolver for
your VPC, then it will automatically return the local endpoint IP address instead of the Internet facing one.
However, if you have your VPC setup to not use Route53 as its DNS resolver then you'll need to override the
endpoint that the Lambda function uses for the SNS and Secrets Manager services by setting the snsEndPointHostname,
and secretsManagerEndPointHostname configuration variables (you'll see how to do that below). You should set
them to the "local" DNS name of the respective endpoints.

### Lambda Function
There are a few things you need to do to properly configure the Lambda function.
- Give it the permissions listed above.
- Put it into the same VPC and subnet as the FSxN file system.
- Increase the total run time to at least 10 seconds. You might have to raise that if you have a lot of components in your FSxN file system. However, if you have to raise it to more than a minute, it could be an issue with the endpoint causing the calls to the AWS services to hang. See the Endpoint section above for more information.
- Provide for the base configuration via environment variables and a configuration file.
- Create the "Matching Conditions" file, that specifies when the Lambda function should send an alert.
- Set up an EventBridge Schedule rule to trigger the function on a regular basis.

#### Configuration Parameters
Below is a list of parameters that are used to configure the program. Some parameters are required to be set
for the program to function, and others that are optional. Some of the optional ones are still required but
will have a usable default value if the parameter is not set. For the parameters that aren't required to be
set via an environment variable, they can be set by creating a "configuration file" and putting the assignments
in it. The assignments should be of the form "parameter=value". The default filename for the configuration
file is what you set the OntapAdminServer variable to plus the string "-config". If you want to use a different
filename, then set the configFilename environment variable to the name of your choosing.

**NOTE:** Parameter names are case sensitive. 

|Parameter Name | Required | Required as an Environment Variable | Default Value | Description |
|:--------------|:---------|:------------------------------------|:--------------|:------------|
|s3BucketName   | Yes | Yes | None | Set to the name of the S3 bucket you want the program to store events to. It will also read the matching configuration file from this bucket. |
|s3BucketRegion | Yes | Yes | None | Set to the region the S3 bucket resides in. |
|configFilename | No | Yes | OntapAdminServer + "-config" | Set to the filename (S3 object) that contains parameter assignments. It's okay if it doesn't exist, as long as there are environment variables for all the required parameters. |
| emsEventsFilename | No | No | OntapAdminServer + "-emsEvents" | Set to the filename (S3 object) that you want the program to store the EMS events that it alerts on into. This file will be created as necessary. |
| smEventsFilesname | No | No | OntapAdminServer + "-smEvents" | Set to the filename (S3 object) that you want the program to store the SnapMirror alerts into. This file will be created as necessary.  |
| smRelationshipsFilename | No | No | OntapAdminServer + "-smRelationships" | Set to the filename (S3 object) that you want the program to store the SnapMirror relationships into. This file will be created as necessary. |
| storageEventsFilename | No | No | OntapAdminServer + "-storageEvents" | Set to the filename (S3 object) that you want the program to store the Storage alerts into. This file will be created as necessary. |
| quotaEventsFilename | No | No | OntapAdminServer + "-quotaEvents" | Set to the filename (S3 object) that you want the program to store the Quota alerts into. This file will be created as necessary. |
| systemStatusFilename | No | No | OntapAdminServer + "-systemStatus" | Set to the filename (S3 object) that you want the program to store the overall system status information into. This file will be created as necessary. |
| snsTopicArn  | Yes | No | None | Set to the ARN of the SNS topic you want the program to publish alert messages to. |
| snsRegion | Yes | No | None | The region where the SNS topic resides. |
| conditionsFilename | Yes | No | OntapAdminServer + "-conditions" | Set to the filename (S3 object) where you want the program to read the matching condition information from. |
| secretName | Yes | No | None | Set to the name of the secret within the AWS Secrets Manager that holds the ONTAP credentials. |
| secretRegion | Yes | No | None | Set to the region where the secretName is stored. |
| secretUsernameKey | Yes | No | None | Set to the key name within the secretName that holds the username portion of the ONTAP credentials. |
| secretPasswordKey | Yes | No | None | Set to the key name within the secretName that holds the password portion of the ONTAP credentials. |
| snsEndPointHostname | No | No | None | Set to the DNS hostname assigned to the SNS endpoint created above. | 
| secretsManagerEndPointHostname	 | No | No | None | Set to the DNS hostname assigned to the SecretsManager endpoint created above. |
| syslogIP | No | No | None | To have the program send syslog messages anytime it sends an SNS message set this to the IP address (or hostname) of the syslog server to send the messages to. |

#### Matching Conditions File
To specify which events you want to be alerted on, you create a "Matching Conditions" file. The format of the
file is JSON. JSON is basically a series of "key" : "value" pairs. Where the value can be object that also has
"key" : "value" pairs. For more information about the format of a JSON file, please refer to this page. The JSON
schema in this file is made up of an array with a key name of "services". Each element of the "services" array
is an object with two keys. The first key is “name" which specifies the name of the service it is going to provide
matching conditions (rules) for. The second key is "rules" which is an array of objects that provide the specific
matching conditions. Note that each service's rules has its own unique schema. The following is the unique schema
for each of the service's rules.

##### Matching condition schema for System Health
Each rule should be an object with one, or more, of the following keys:

- versionChange - Is a Boolean (true, false) and if 'true' will send an alert when the ONTAP version changes. If it is set to false, it will not report on version changes.
- failover - Is a Boolean (true, false) and if 'true' will send an alert if the FSxN cluster is running on its standby node. If it is set to false, it will not report on failover status.
- networkInterfaces - Is a Boolean (true, false) and if 'true' will send an alert if any of the network interfaces are down.  If it is set to false, it will not report on any network interfaces that are down.

##### Matching condition schema for EMS Messages
Each rule should be an object with three keys:

- "name" - Which will match on the EMS event name.
- "message" - Which will match on the EMS event message text.
- "severity" - Which will match on the severity of the EMS event (debug, informational, notice, error, alert or emergency).
Note that all values to each of the keys are used as a regular expressions against the associated EMS component. So, for example, if you want to match on any event message text that starts with “snapmirror” then you would put “^snapmirror”. The “^” character matches the beginning on the string. If you want to match on a specific EMS event name, then you should anchor it with an regular express that starts with “^” for the beginning of the string and ends with “$” for the end of the string. For example, “^arw.volume.state$’.  For a complete explanation of the regular expression syntax and special characters, please see the Python documentation found here Regular expression operations.

##### Matching condition schema for SnapMirror relationships
Each rule should be an object with one, or more, of the following keys:

- maxLagTime - Specifies the maximum allowable time, in seconds, since the last successful SnapMirror update before an alert will be sent.
- stalledTransferSeconds - Specifies the minimum number of seconds that have to transpire before a SnapMirror transfer will be considered stalled.
- health - Is a Boolean (true, false) which specifies if you want to alert on a healthy relationship (true) or an unhealthy relationship (false).

##### Matching condition schema for Storage
Each rule should be an object with one, or more, of the following keys:

- aggrWarnPercentUsed - Specifies the maximum allowable physical storage (aggregate) utilization (between 0 and 100) before an alert is sent.
- aggrCriticalPercentUsed - Specifies the maximum allowable physical storage (aggregate) utilization (between 0 and 100) before an alert is sent.
- volumeWarnPercentUsed  - Specifies the maximum allowable volume utilization (between 0 and 100) before an alert is sent.
- volumeCriticalPercentUsed - Specifies the maximum allowable volume utilization (between 0 and 100) before an alert is sent. 

##### Matching condition schema for Quota
Each rule should be an object with one, or more, of the following keys:

- maxHardQuotaSpacePercentUsed - Specifies the maximum allowable storage utilization (between 0 and 100) against the hard quota limit before an alert is sent.
- maxSoftQuotaSpacePercentUsed - Specifies the maximum allowable storage utilization (between 0 and 100) against the soft quota limit before an alert is sent.
- maxQuotaInodesPercentUsed  - Specifies the maximum allowable inode utilization (between 0 and 100) before an alert is sent.

##### Example Matching conditions file:
```
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
          "severity": "notice|info|error|alert|emergency",
          "message": ""
        }
      ]
    },
    {
      "name": "snapmirror",
      "rules": [
        {
          "maxLagTime": 120
        },
        {
          "healthy": false
        },
        {
          "stalledTransferSeconds": 60
        }
      ]
    },
    {
      "name": "storage",
      "rules": [
        {
          "aggrWarnPercentUsed": 80
        },
        {
          "aggrCriticalPercentUsed": 95
        },
        {
          "volumeWarnPercentUsed": 85
        },
        {
          "volumeCriticalPercentUsed": 90
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
- Any SnapMirror relationship with a lag time more than 86400 seconds (24 hours).
- Any SnapMirror relationship that has a non-healthy status.
- Any SnapMirror update that hasn't had any flow of data in 600 seconds (10 minutes).
- If the cluster aggregate is more than 80% full.
- If the cluster aggregate is more than 95% full.
- If any volume is more than 85% full.
- if any volume is more than 90% full.
- If any quota policies where the space utilization is more than 95% of the hard limit.
- If any quota policies where the space utilization is more than 100% of the soft limit.
- If any quota policies are showing any inode utilization more than 95%
A matching conditions file must be created and stored in the S3 bucket with the name given as the "conditionsFilename" configuration variable. Feel free to use the example above as a starting point. Note that you should ensure it is in valid JSON format, otherwise the program will fail to load the file. There are various programs and websites that can validate a JSON file for you.
