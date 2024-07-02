# Deploy an ONTAP FSx file-system using Terraform
This is a Terraform module which creates an FSx for NetApp ONTAP file system in a multi-AZ fashion, including an SVM, a Security-Group and a FlexVolume in that file system, using AWS Terraform provider. 
This repo should be sourced as a terraform module, and does not need to be cloned locally!
Follow the instructions below to use this sample in your environment.
> [!NOTE]
> This module does not support scale-out! One ha pair per deployment. 

## Table of Contents
* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Repository Overview](#repository-overview)
* [Author Information](#author-information)
* [License](#license)

## Introduction

### What to expect

Calling this terraform module will result the following: 
* Create a new AWS Security Group in your VPC with the following rules:
    - **Ingress** allow all ICMP traffic
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
    - **Egress** allow all traffic
* Create a new FSx for Netapp ONTAP file-system in your AWS account named "_terraform-fsxn_". The file-system will be created with the following configuration parameters:
    * 1024Gb of storage capacity
    * Multi AZ deployment type
    * 128Mbps of throughput capacity 

* Create a Storage Virtual Maching (SVM) in this new file-system named "_first_svm_"
* Create a new FlexVol volume in this SVM named "_vol1_" with the following configuration parameters:
    * Size of 1024Mb
    * Storage efficiencies mechanism enabled
    * Auto tiering policy with 31 cooling days

> [!NOTE]
> All of the above configuration parameters can be modified for your preference by assigning your own values in the module block!

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

To list configuration data, use the [`aws configire list`](https://docs.aws.amazon.com/cli/latest/reference/configure/list.html) command. This command lists the profile, access key, secret key, and region configuration information used for the specified profile. For each configuration item, it shows the value, where the configuration value was retrieved, and the configuration variable name.

## Usage

This directory contains a shared Terraform module that can be referenced remotely. **No need to clone the repository in order to use it!**
To reference this module, create a new terraform folder in your local environment, add a main.tf file and modify it according to the instructions below.

### AWS provider block

Add the AWS provider block to your local root `main.tf` file with the required configuration. For more information check [the docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Example:
```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.25"
    }
  }
}

provider "aws" {
  # Configuration options
}
```

### Reference this module

Add the following module block to your local `main.tf` file.
Make sure to replace all values within `< >` with your own variables.

```hcl
module "fsxontap" {
    source = "github.com/Netapp/FSx-ONTAP-samples-scripts/Terraform/deploy-fsx-ontap/module"

    vpc_id = "<YOUR-VPC-ID>"
    fsx_subnets = {
        primarysub   = "<YOUR-PRIMARY-SUBNET>"
        secondarysub = "<YOUR-SECONDAY-SUBNET>"
    }
    create_sg = <true / false> // true to create Security Group for the Fs / false otherwise
    cidr_for_sg = "<YOUR-CIDR-BLOCK>"
    fsx_admin_password = "<YOUR_PASSWORD>"
    tags = {
        Terraform   = "true"
        Environment = "dev"
    }
}
```

> [!NOTE]
> To Override default values assigned to other variables in this module, add them to this source block as well. The above source block includes the minimum requirements only.

> [!NOTE]
> The default deployment type is: MULTI_AZ_1. For SINGLE AZ deployment, override the `fsx_deploy_type` variable in the module block, and make sure to only provide one subnet as `primarysub`

Please read the vriables descriptions in `variables.tf` file for more information regarding the variables passed to the module block.

### Example main.tf file

For a quick and easy start, copy and paste the below example to your main.tf file and modify the variables with your enviroonment's values.

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.25"
    }
  }
}

provider "aws" {
    shared_config_files      = ["$HOME/.aws/conf"]
    shared_credentials_files = ["$HOME/.aws/credentials"]
    region = "us-west-2"
}


module "fsxontap" {
    source = "github.com/Netapp/FSx-ONTAP-samples-scripts/Terraform/deploy-fsx-ontap/module"

    vpc_id = "vpc-111111111"
    fsx_subnets = {
        "primarysub" = "subnet-11111111"
        "secondarysub" = "subnet-2222222"
    }
    create_sg = true
    cidr_for_sg = "10.0.0.0/8"
    fsx_admin_password = "yourpassword"
    route_table_ids = ["rtb-111111"]
    tags = {
        Terraform   = "true"
        Environment = "dev"
    }
}


```

### Install the module

Whenever you add a new module to a configuration, Terraform must install the module before it can be used. Both the `terraform get` and `terraform init` commands will install and update modules. The `terraform init` command will also initialize backends and install plugins.

Command:
```shell
terraform init
```
Output:

```shell
Initializing the backend...
Initializing modules...
Downloading git::https://github.com/Netapp/FSx-ONTAP-samples-scripts.git for fsxontap...
- fsxontap in .terraform/modules/fsxontap/Terraform/deploy-fsx-ontap/module

Initializing provider plugins...
- Finding hashicorp/aws versions matching "5.25.0"...
- Installing hashicorp/aws v5.25.0...
- Installed hashicorp/aws v5.25.0 (signed by HashiCorp)

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

### Plan and Apply the cofiguration

Now that your new module is installed and configured, run the `terraform plan` command to create an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:
```shell
terraform plan
```
Ensure that the proposed changes match what you expected before you apply the changes!

Once confirmed, run the `terraform apply` command followed by `yes` to execute the Terrafom code and apply the changes proposed in the `plan` step:
```shell
terraform apply -y
```

<!-- BEGIN_TF_DOCS -->

## Repository Overview

### Providers

| Name | Version |
|------|---------|
| aws | n/a |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| backup_retention_days | The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days. | `number` | `0` | no |
| cidr_for_sg | cidr block to be used for the created security ingress rules. | `string` | `"10.0.0.0/8"` | no |
| create_sg | Determines whether the SG should be deployed as part of this execution or not | `bool` | `true` | no |
| daily_backup_start_time | A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set. | `string` | `"00:00"` | no |
| disk_iops_configuration | The SSD IOPS configuration for the Amazon FSx for NetApp ONTAP file system | `map(any)` | <pre>{<br>  "mode": "AUTOMATIC"<br>}</pre> | no |
| fsx_capacity_size_gb | The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608 | `number` | `1024` | no |
| fsx_deploy_type | The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1 | `string` | `"MULTI_AZ_1"` | no |
| fsx_maintenance_start_time | The preferred start time (in d:HH:MM format) to perform weekly maintenance, in the UTC time zone. | `string` | `"1:00:00"` | no |
| fsx_secret_name | The name of the secure where the FSxN passwood is stored | `string` | `""` | no |
| fsx_subnets | The subnets from where the file system will be accessible from. For MULTI_AZ_1 deployment type, provide both primvary and secondary subnets. For SINGLE_AZ_1 deployment type, only the primary subnet is used. | `map(string)` | <pre>{<br>  "primarysub": "subnet-111111111",<br>  "secondarysub": "subnet-222222222"<br>}</pre> | no |
| fsx_tput_in_MBps | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096. | `number` | `128` | no |
| kms_key_id | ARN for the KMS Key to encrypt the file system at rest, Defaults to an AWS managed KMS Key. | `string` | `null` | no |
| root_vol_sec_style | Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume. | `string` | `"UNIX"` | no |
| route_table_ids | Specifies the VPC route tables in which your file system's endpoints will be created. You should specify all VPC route tables associated with the subnets in which your clients are located. By default, Amazon FSx selects your VPC's default route table. | `list(any)` | `null` | no |
| security_group_id | If you are not creating the SG, provide the ID of the SG to be used | `string` | `""` | no |
| source_security_group_id | The ID of the security group to allow access to the FSxN file system. | `string` | `""` | no |
| svm_name | The name of the Storage Virtual Machine | `string` | `"first_svm"` | no |
| tags | Tags to be applied to the resources | `map(any)` | <pre>{<br>  "Name": "terraform-fsxn"<br>}</pre> | no |
| vol_info | Details for the volume creation | `map(any)` | <pre>{<br>  "bypass_sl_retention": false,<br>  "cooling_period": 31,<br>  "copy_tags_to_backups": false,<br>  "efficiency": true,<br>  "junction_path": "/vol1",<br>  "sec_style": "UNIX",<br>  "size_mg": 1024,<br>  "skip_final_backup": false,<br>  "tier_policy_name": "AUTO",<br>  "vol_name": "vol1",<br>  "vol_type": "RW"<br>}</pre> | no |
| vol_snapshot_policy | Specifies the snapshot policy for the volume | `map(any)` | `null` | no |
| vpc_id | The ID of the VPC in which the FSxN fikesystem should be deployed | `string` | `""` | no |

### Outputs

| Name | Description |
|------|-------------|
| my_filesystem_id | The ID of the FSxN Filesystem |
| my_fsx_ontap_security_group_id | The ID of the FSxN Security Group |
| my_svm_id | The ID of the FSxN Storage Virtual Machine |
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
