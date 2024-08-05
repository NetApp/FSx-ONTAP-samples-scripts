# Deploy an Amazon FSx for NetApp ONTAP with CloudFormation
This repository contains a CloudFormation template that deploys an Amazon FSx for NetApp ONTAP file system. 

## Configuration
The CloudFormation template allowed the following configuration parameters to be provided:

|Property|type|Required|Notes|
|---|---|---|---|
|FileSystemType|String|Yes|This should be set to `ONTAP` to deploy an FSx for ONTAP file system.|
|KmsKeyId|String|No|The ID of the AWS Key Management Service (AWS KMS) key used to encrypt the data at rest. If not provided, a key managed by AWS will  be used.|
|SecurityGroupIds|Array of Strings|No|While technically not required; without a security group you won't be able to access the FSx for ONTAP file system.|
|StorageCapacity|Integer|Yes|The number of gigabytes of SSD storage to provision. If you are using tiering, this is the amount to allocate in the "performance tier." The minimum is 1024 (i.e. 1TiB) per HA pair. The maximum is 1,048,576 (i.e. 1 PiB).|
|SubnetIds|string|Yes|These are the subnets that a Network Interface will be created that allows access to the FSx for ONTAP storage and management endpoints.<br><br>When deploying in a single availability zone, you can only specify one subnet. If deploying in a multi availability zone environment, then you need to specify two subnets. In the OntapConfiguration you will specify which subnet contains the primary node of the HA pair.|
|OntapConfiguration|Structure|Yes|See the below table for the properties that make up this structure.|

This table list the properties that make up the OntapConfiguration structure:

|Property|type|Required|Notes|
|---|---|---|---|
|AutomaticBackupRetentionDays|Integer|No|Sets the number of days to retain an automatic backup. Defaults to 30. Set to 0 to disable automatic backups.|
|DailyAutomaticBackupStartTime|String|No|Sets when the daily automatic backup should occur. The format should be HH:MM. It should be in 24-hour notation with each number zero filled. The time zone is always UTC. For example, "22:05" means 5 minutes after 10PM UTC. The default is randomly chosen by AWS.
|DeploymentType|String|Yes|Sets the generation of file servers to use, and whether you want both nodes of the HA pair to be deploy within a single availability zone or spread across multiple availability zones. The supported vales are:<br><ul><li>MULTI_AZ_1 - Deploy generation 1 file servers with each node of the HA pair in different availability zones.</li><li>MULTI_AZ_2 - Deploy generation 2 file servers with each node of the HA pair in different availability zones.</li><li>SINGLE_AZ_1 - Deploy generation 1 file servers with both nodes of the HA pair in the same availability zone.</li><li>SINGLE_AZ_2 - Deploy generation 2 file servers with all nodes in the same availability zone. This specific deployment type allows you to deploy from one to twelve HA pairs in a single file system. Use the HAPairs property to specify how many HA pairs you want deployed.</li></ul>|
|DiskIopsConfiguration|Structure|No|Sets the maximum IOPS (I/Os per second) the file system can have when accessing the SSDs. It does not set the maximum IOPS for the file system itself, since the file system can response with data that is already in its cache.  The definition of the structure is below.|
|EndpointIpAddress|String|No|Set the CIDR (i.e. IP Address range) that the file system endpoints will be allocated from. This can only be specified for multiple availability zone deployments. For more information how this parameter is used, please visit this webpage. The default is 198.19.0.0/16.|
|FsxAdminPassword|String|No|Sets the default user's (fsxadmin) password. It is not recommended to store the password in plain text anywhere, so the best practice is to not set it when you deploy the file system, but set it later via the AWS console, CLI or API. Or, you can use CloudFormation to read a secret to set the password.|
|HPApairs|Integer|No|Allows you to set the number of HA pairs to deploy in a single file system. Only used when the DeploymentType is set to "SINGLE_AZ_2". Note, you cannot change the number of nodes that are in a file system once it has been deployed. If you need to change it, will have to deploy a new filesystem and migrate your data to it. The default is number of HA pairs is 1.|
|PreferredSubnetId|String|No|Required in multiple availability zone deployments. This allows you to specify which subnet you want the primary node to be connected to. It should be one of the subnets specified in the SubnetIds property.|
|RouteTableIds|Array of Strings|No|This allows you to specify any route tables you want CloudFormation to update so that it will have a route to the file system. This is only needed for a multiple availability zone deployment. The default is the VPC's default route table.|
|ThroughputCapacity|Integer|No|This sets the throughput capacity of Gen 1 based file system (i.e. when the DeploymentType is set to "SINGLE_AZ_1" or "MULTI_AZ_1"). The default is based on the amount of storage provisioned. Valid values are:<br><ul><li>128</li><li>256</li><li>512</li><li>1024</li><li>2048</li><li>4096</li></ul>**Note**: You can only specify ThroughputCapacity or ThroughputCapacityPerHAPair but not both. And, since you can use ThroughputCapacityPerHAPair for all deployment types, I would avoid using this one.|
|ThroughputCapacityPerHaPair|Integer|No|This sets the throughput capacity of each HA pair. This property can be used for both generation 1 and generation 2 type deployments. Use the supported values above if using it with generation 1 type deployment.<br><br>For generation 2 type deployments (i.e. when the deployment type is "MULTI_AZ_2" or "SINGLE_AZ_2") and with only 1 HA pair, the following are the allowed values:<ul><li>384</li><li>768</li><li>1536</li><li>3072</li><li>6144</li></ul>For generation 2 type deployments with more than 1 HA pair, the following are the allowed values:<ul><li>1536</li><li>3072</li><li>6144</li></ul>The default is based on the amount of storage provisioned.<br>**Note:** You can only specify ThroughputCapacity or ThroughputCapacityPerHAPair but not both.|
|WeeklyMaintenanceStartTime|String|No|AWS reserves the right to perform maintenance on the file system once a week. This allows you to set the time and day of that maintenance. The format of the string should be D:HH:MM, where D specifies the day of the week, where 1 is Monday and 7 is Sunday. The time-of-day portion should be in 24-hour format, with each number zero filled. The time zone is always in the UTC time zone. For example, "22:05" means 5 minutes after 10PM UTC. The default is randomly selected by AWS.|

This table list the properties that make up the DiskIopsConfiguration structure:

|Property|type|Required|Notes|
|---|---|---|---|
|Mode|String|Yes|The mode parameter can be "USER_PROVISIONED" or "AUTOMATIC". If it is set to "AUTOAMTIC" then you don't need to specify the Iops since they will automatically be set to 3 Iops per GB provisioned. The default is AUTOMATIC.|
|Iops|Integer|No|Only required if the mode is set to "USER_PROVISIONED". It sets the maximum number of Iops you are allowed when accessing the SSD disks.|

## Usage
There are two main ways of deploying a CloudFormation "Stack" using a template file. Either through the AWS web console, or via the aws CLI (Command Line Interface). The benefit of using the AWS Console, is that it will prompt you for the parameters, whereas the CLI will require you to pass the parameters via command line arguments.
### Using the AWS Console to deploy a CloudFormation Template
To use the console, first log into the AWS console (https://console.aws.com) and then go the CloudFormation page. From there select "Stacks," then "Create stack" and finally "With new resources (standard)":
![Create Stack](./images/create-stack-01.png)
On the next page, select "Choose an existing template." As you can see there are multiple ways to pass the template file to CloudFormation. If you stored your template file in an S3 bucket, click on "Amazon S3 URL" and filling the URL to the file. Otherwise, if you just are keeping the template as a file on your PC click on "Upload a template file" and then click on "Choose File." 
![Choose Template](./images/create-stack-02.png)
That will bring up a file selection box. Find the file that holds your template and select it. After AWS has read in your file, click "Next."

That should bring you to a page similar to one below, where you fill in the Stack Name and the parameters from your template:
![Fill in Parameters](./images/create-stack-03.png)

The list of parameters will depend on the template you are using. Once you have the parameters filled in, click "Next" at the bottom right of the page. This will bring you to a page where you can set some various options. For this exercise just leave everything with the defaults and click "Next" on the bottom right of the page.

The next page just lists all the values to the parameters you provided, as well as any configuration changes to made on the previous page. You just need to click "Submit" at the bottom right of the page for AWS to start building your FSx for ONTAP file system.

### Using the AWS CLI to deploy a CloudFormation Template
When it comes to passing the template file to CloudFormation using the CLI you can either specify a URL to an S3 bucket, using the --template-url option, or pass the entire body of the template with the --template-body option. You also have to specify all the parameters you want to set as well. Here is an example:
```
body=$(cat template-file-name)
aws cloudformation create-stack --stack-name "deploy-FSx-for-ontap" --template-body "$body" --parameters \
 ParameterKey=Name,ParameterValue=fsx-deployed-from-cloudformation \
 ParameterKey=DeploymentType,ParameterValue=MULTI_AZ_1 \
 ParameterKey=PrimarySubnet,ParameterValue=subnet-11111111 \
 ParameterKey=SecondarySubnet,ParameterValue=subnet-22222222 \
 ParameterKey=RouteTableIds,ParameterValue=rtb-12345678 \
 ParameterKey=SecurityGroupIds,ParameterValue=sg-00000000000000000 \
 ParameterKey=StorageCapacity,ParameterValue=1024 \
 ParameterKey=ThroughputCapacity,ParameterValue=128
```
Of course change the subnet, routing table and security group ID to match your environment.
