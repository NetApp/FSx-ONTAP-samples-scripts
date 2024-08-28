# Deploy an ONTAP FSx file-system using Terraform
## Table of Contents
* [Introduction](#introduction)
* [Repository Overview](#repository-overview)
* [What to expect](#what-to-expect)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Terraform Overview](#terraform-overview)
* [Author Information](#author-information)
* [License](#license)

## Introduction
This sample demonstrates how to deploy an FSx for NetApp ONTAP file system, including an SVM and a FlexVolume in that file system, using AWS Terraform provider in a standalone Terraform module.
Follow the instructions below to use this sample in your own environment.
### Repository Overview
This is a standalone Terraform configuration repository that contains the following files:
* **main.tf** - Contains the configuration of the AWS FSx for ONTAP based on the variables set in the `variables.tf` file.
* **output.tf** - Contains output declarations of the resources created by this Terraform configuration.
* **security_groups.tf** - Contains security group configurations for the FSxN file system.
* **variables.tf** - Contains the variable definitions that allows you to customize the deployment.

### What to expect
Running this terraform sample will result the following:
* Optionally a new AWS Security Group in your VPC with the following rules:
    - **Ingress** allow ICMP traffic
    - **Ingress** allow nfs port 111 (both TCP and UDP)
    - **Ingress** allow cifs TCP port 139
    - **Ingress** allow snmp ports 161-162 (both TCP and UDP)
    - **Ingress** allow smb cifs TCP port 445
    - **Ingress** allow nfs mount port 635 (both TCP and UDP)
    - **Ingress** allow kerberos TCP port 749
    - **Ingress** allow nfs port 2049 (both TCP and UDP)
    - **Ingress** allow nfs lock and monitoring 4045-4046 (both TCP and UDP)
    - **Ingress** allow nfs quota TCP 4049
    - **Ingress** allow Snapmirror Intercluster communication TCP port 11104
    - **Ingress** allow Snapmirror data transfer TCP port 11105
    - **Ingress** allow ssh port 22
    - **Ingress** allow https port 443
    - **Egress** allow all out bound traffic

* Two new AWS secrets. One that contains the fsxadmin password and another that contains the SVM admin password.

* A new FSx for Netapp ONTAP file-system. Much of the configuration is defined in the `variables.tf` file, but the following are the default values:
    * 1024Gb of storage capacity
    * Generation 1 Multi AZ deployment type
    * 128Mbps of throughput capacity
    * 1 HA pair
    * 1 Storage Virtual Machine (SVM)
    * 1 FlexVol volume with the following configuration parameters:
        * Size of 2TB - Thin provisioned
        * Junction path of /vol1
        * Security style of UNIX
        * Storage efficiencies enabled
        * Auto tiering policy with 31 cooling days
        * post-delete backup disabled

## Prerequisites

1. [Terraform prerequisites](#terraform)
2. [AWS prerequisites](#aws-account-setup)

### Terraform

| Name | Version |
|------|---------|
| terraform | >= 1.6.6 |
| aws provider | >= 5.25 |

### AWS Account Setup

* You must have an AWS Account with necessary permissions to create and manage resources
* Configure your AWS Credentials on the server running this Terraform module. This can be derived from several sources, which are applied in the following order:
    1. Parameters in the provider configuration
    2. Environment variables
    3. Shared credentials files
    4. Shared configuration files
    5. Container credentials
    6. Instance profile credentials and Region

    This order matches the precedence used by the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-precedence) and the [AWS SDKs](https://aws.amazon.com/tools/).

> [!NOTE]
> In this sample, the AWS Credentials were configured through [AWS CLI](https://aws.amazon.com/cli/), which adds them to a shared configuration file (option 4 above). Therefore, this documentation only provides guidance on setting-up the AWS credentials with shared configuration file using AWS CLI.

#### Configure AWS Credentials using AWS CLI

The AWS Provider can source credentials and other settings from the shared configuration and credentials files. By default, these files are located at `$HOME/.aws/config` and `$HOME/.aws/credentials` on Linux and macOS, and `"%USERPROFILE%\.aws\credentials"` on Windows.

There are several ways to set your credentials and configuration setting using AWS CLI. We will use [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure/index.html) command:

Run the following command to quickly set and view your credentails, region, and output format. The following example shows sample values:

```shell
$ aws configure
AWS Access Key ID [None]: < YOUR-ACCESS-KEY-ID >
AWS Secret Access Key [None]: < YOUR-SECRET-ACCESS-KE >
Default region name [None]: < YOUR-PREFERRED-REGION >
Default output format [None]: json
```

To list configuration data, use the [`aws configire list`](https://docs.aws.amazon.com/cli/latest/reference/configure/list.html) command. This command lists the profile,
access key, secret key, and region configuration information used for the specified profile. For each configuration item, it shows the value, where the configuration
value was retrieved, and the configuration variable name.

## Usage

### 1. Clone the repository
In your server's terminal, navigate to the location where you wish to store this Terraform repository, and clone the repository using your preferred authentication type. In this example we are using HTTPS clone:

```shell
git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts.git
```

### 2. Navigate to the directory
```shell
cd FSx-ONTAP-samples-scripts/Terraform/deploy-fsx-ontap/standalone-module
```

### 3. Initialize Terraform
This directory represents a standalone Terraform module. Run the following command to initialize the module and install all dependencies:
```shell
terraform init
```

A successful initialization should display the following output:
```shell
Initializing the backend...
Initializing modules...
Downloading git::https://github.com/Netapp/FSx-ONTAP-samples-scripts.git for fsxn_rotate_secret...
- fsxn_rotate_secret in .terraform/modules/fsxn_rotate_secret/Management-Utilities/fsxn-rotate-secret/terraform
Downloading git::https://github.com/Netapp/FSx-ONTAP-samples-scripts.git for svm_rotate_secret...
- svm_rotate_secret in .terraform/modules/svm_rotate_secret/Management-Utilities/fsxn-rotate-secret/terraform

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 5.25.0"...
- Finding latest version of hashicorp/random...
- Finding latest version of hashicorp/archive...
- Installing hashicorp/aws v5.59.0...
- Installed hashicorp/aws v5.59.0 (signed by HashiCorp)
- Installing hashicorp/random v3.6.2...
- Installed hashicorp/random v3.6.2 (signed by HashiCorp)
- Installing hashicorp/archive v2.4.2...
- Installed hashicorp/archive v2.4.2 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
You can see that Terraform recognizes the modules required by our configuration: `hashicorp/aws`.

### 4. Update Variables

Open the **`variables.tf`** file in your preferred text editor. Update the values of the variables to match your
preferences and save the file. This will ensure that the Terraform code deploys resources according to your specifications.

### 5. Create a Terraform plan
Run the following command to create an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:
```shell
terraform plan
```
Ensure that the proposed changes match what you expected before you apply the changes!

### 7. Apply the Terraform plan
Run the following command to execute the Terrafom code and apply the changes proposed in the `plan` step:
```shell
terraform apply
```

<!-- BEGIN_TF_DOCS -->

## Repository Overview

### Providers

| Name | Version |
|------|---------|
| aws | >= 5.25.0 |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_account_id | The AWS account ID. Used to create account specific permissions on the secrets that are created. Use the default for less specific permissions. | `string` | `"*"` | no |
| backup_retention_days | The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days. | `number` | `0` | no |
| cidr_for_sg | The cidr block to be used for the created security ingress rules. Set to an empty string if you want to use the source_sg_id as the source. | `string` | `"10.0.0.0/8"` | no |
| create_sg | Determines whether the Security Group should be created as part of this deployment or not. | `bool` | `true` | no |
| daily_backup_start_time | A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set. | `string` | `"00:00"` | no |
| disk_iops_configuration | The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provisioned) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVISIONED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in double quotes) and 'iops=number' where number is between 1 and 160000. | `map(any)` | `{}` | no |
| endpoint_ip_address_range | The IP address range that the FSxN file system will be accessible from. This is only used for Multi AZ deployment types and must be left a null for Single AZ deployment types. | `string` | `null` | no |
| fsx_capacity_size_gb | The storage capacity in GiBs of the FSxN file system. Valid values between 1024 (1 TiB) and 1048576 (1 PiB). Gen 1 deployment types are limited to 192 TiB. Gen 2 Multi AZ is limited to 512 TiB. Gen 2 Single AZ is limited to 1 PiB. | `number` | `1024` | no |
| fsx_deploy_type | The file system deployment type. Supported values are 'MULTI_AZ_1', 'SINGLE_AZ_1', 'MULTI_AZ_2', and 'SINGLE_AZ_2'. MULTI_AZ_1 and SINGLE_AZ_1 are Gen 1. MULTI_AZ_2 and SINGLE_AZ_2 are Gen 2. | `string` | `"MULTI_AZ_1"` | no |
| fsx_name | The name to assign to the FSxN file system. | `string` | `"terraform-fsxn"` | no |
| fsx_region | The AWS region where the FSxN file system to be deployed. | `string` | `"us-west-2"` | no |
| fsx_subnets | The primary subnet ID, and secondary subnet ID if you are deploying in a Multi AZ environment, file system will be accessible from. For MULTI_AZ deployment types both subnets are required. For SINGLE_AZ deployment type, only the primary subnet is used. | `map(any)` | <pre>{<br>  "primarysub": "subnet-22222222",<br>  "secondarysub": "subnet-33333333"<br>}</pre> | no |
| fsx_tput_in_MBps | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096 for Gen 1, and 384, 768, 1536, 3072 and 6144 for Gen 2. | `string` | `"128"` | no |
| ha_pairs | The number of HA pairs in the file system. Valid values are from 1 through 12. Only single AZ Gen 2 deployment type supports more than 1 HA pair. | `number` | `1` | no |
| kms_key_id | ARN for the KMS Key to encrypt the file system at rest. Defaults to an AWS managed KMS Key. | `string` | `null` | no |
| maintenance_start_time | The preferred start time to perform weekly maintenance, in UTC time zone. The format is 'D:HH:MM' format. D is the day of the week, where 1=Monday and 7=Sunday. | `string` | `"7:00:00"` | no |
| root_vol_sec_style | Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume. | `string` | `"UNIX"` | no |
| route_table_ids | An array of routing table IDs that will be modified to allow access to the FSxN file system. This is only used for Multi AZ deployment types and must be left as null for Single AZ deployment types. | `list(string)` | `null` | no |
| secret_name_prefix | The prefix to the secret names created that will contain the FSxN passwords (system, and SVM). | `string` | `"fsxn-secret"` | no |
| secret_region | The AWS region where the secrets for the FSxN file system and SVM will be deployed. | `string` | `"us-west-2"` | no |
| security_group_ids | If you are not creating the security group, provide a list of the IDs of the security group to be used. | `list(string)` | `[]` | no |
| security_group_name_prefix | The prefix to the security group name that will be created. | `string` | `"fsxn-sg"` | no |
| source_sg_id | The ID of the security group to allow access to the FSxN file system. Set to an empty string if you want to use the cidr_for_sg as the source. | `string` | `""` | no |
| svm_name | The name of the Storage Virtual Machine | `string` | `"fsx"` | no |
| tags | Tags to be applied to the FSxN file system. The format is '{Name1 = value, Name2 = value}' where value should be enclosed in double quotes. | `map(any)` | `{}` | no |
| vol_info | Details for the volume creation | `map(any)` | <pre>{<br>  "cooling_period": 31,<br>  "copy_tags_to_backups": false,<br>  "efficiency": true,<br>  "junction_path": "/vol1",<br>  "sec_style": "UNIX",<br>  "size_mg": 2048000,<br>  "skip_final_backup": true,<br>  "snapshot_policy": "default",<br>  "tier_policy_name": "AUTO",<br>  "vol_name": "vol1"<br>}</pre> | no |
| vpc_id | The VPC ID where the security group will be created. | `string` | `""` | no |

### Outputs

| Name | Description |
|------|-------------|
| my_filesystem_id | The ID of the FSxN Filesystem |
| my_filesystem_management_ip | The management IP of the FSxN Filesystem. |
| my_fsx_ontap_security_group_id | The ID of the FSxN Security Group |
| my_fsxn_secret_name | The name of the secret containing the ONTAP admin password |
| my_svm_id | The ID of the FSxN Storage Virtual Machine |
| my_svm_management_ip | The management IP of the Storage Virtual Machine. |
| my_svm_secret_name | The name of the secret containing the SVM admin password |
| my_vol_id | The ID of the ONTAP volume in the File System |

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

<!-- END_TF_DOCS -->

© 2024 NetApp, Inc. All Rights Reserved.
