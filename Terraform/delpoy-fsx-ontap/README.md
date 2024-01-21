# Deploy an ONTAP FSx file-system using Terraform
This is a Terraform module which creates an FSx for NetApp ONTAP file system, including an SVM, a Security-Group and a FlexVolume in that file system, using AWS Terraform provider. 
This repo can be sourced as a terraform module.
Follow the instructions below to use this sample in your own environment.

## Table of Contents
* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Author Information](#author-information)
* [License](#license)

## Introduction
### Repository Overview
This is a Terraform module that contains the following files:
* **main.tf** - The main set of configuration for this terraform module

* **variables.tf** - Contains the variable definitions and assignments for this sample. Exported values will override any of the variables in this file. 

* **output.tf** - Contains output declarations of the resources created by this Terraform module. Terraform stores output values in the configuration's state file

### What to expect

Running this terraform module will result the following:
* Create a new AWS Security Group in your VPC with the following rules:
    - **Ingress** allow all ICMP traffic
    - **Ingress** allow nfs port 111 (both TCP and UDP)
    - **Ingress** allow cifc TCP port 139
    - **Ingress** allow snmp ports 161-162 (both TCP and UDP)
    - **Ingress** allow smb cifs TCP port 445
    - **Ingress** alloe bfs mount port 635 (both TCP and UDP)
    - **Egress** allow all traffic
* Create a new FSx for Netapp ONTAP file-system in your AWS account named "_terraform-fsxn_". The file-system will be created with the following configuration parameters:
    * 1024Gb of storage capacity
    * Single AZ deployment type
    * 256Mbps of throughput capacity 

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.25 |

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

    > [NOTE!]
    > In this sample, the AWS Credentials were configured through [AWS CLI](https://aws.amazon.com/cli/), which adds them to a shared configuration file (option 4 above). Therefore, this documentation only provides guidance on setting-up the AWS credentials with shared configuration file using AWS CLI.

    #### Configure AWS Credentials using AWS CLI

    The AWS Provider can source credentials and other settings from the shared configuration and credentials files. By default, these files are located at `$HOME/.aws/config` and `$HOME/.aws/credentials` on Linux and macOS, and `"%USERPROFILE%\.aws\credentials"` on Windows.

    If no named profile is specified, the `default` profile is used. Use the `profile` parameter or `AWS_PROFILE` environment variable to specify a named profile.

    The locations of the shared configuration and credentials files can be configured using either the parameters `shared_config_files` and `shared_credentials_files` or the environment variables `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE`.

    For example:
    ```ruby
    provider "aws" {
        shared_config_files      = ["/Users/tf_user/.aws/conf"]
        shared_credentials_files = ["/Users/tf_user/.aws/creds"]
        profile                  = "customprofile"
    }
    ```

    There are several ways to set your credentials and configuration setting using AWS CLI. We will use [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure/index.html) command:

    Run the following command to quickly set and view your credentails, region, and output format. The following example shows sample values:

    ```shell
    $ aws configure
    AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
    AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
    Default region name [None]: us-west-2
    Default output format [None]: json
    ```

    To list configuration data, use the [`aws configire list`](https://docs.aws.amazon.com/cli/latest/reference/configure/list.html) command. This command lists the profile, access key, secret key, and region configuration information used for the specified profile. For each configuration item, it shows the value, where the configuration value was retrieved, and the configuration variable name.



## Usage

### Reference this module

Add the following module block to your root module `main.tf` file.
Make sure to replace all values within `< >` with your own variables.

```ruby
module "fsxontap" {
    source = "github.com/Netapp/FSxN-Samples/Terraform/deploy-fsx-ontap"

    vpc_id = "<YOUR-VPC-ID>"
    fsx_subnets = {
        "primarysub" = "<YOUR-PRIMARY-SUBNET>"
        "secondarysub" = "<YOUR-SECONDAY-SUBNET>"
    }
    
    tags = {
        Terraform   = "true"
        Environment = "dev"
    }
}
```
   > [NOTE!]
   > To Override default values assigned to other variables in this module, add them to this source block as well. The above source block includes the minimum requirements only.

### AWS provider block

Add the AWS provider block to your root module `main.tf` file with the required configuration. For more information check [the docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Example:
```ruby
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

### Install the module

Whenever you add a new module to a configuration, Terraform must install the module before it can be used. Both the `terraform get` and `terraform init` commands will install and update modules. The `terraform init` command will also initialize backends and install plugins.

```shell
terraform get
Downloading git::https://github.com/Netapp/FSxN-Samples.git for fsxontap...
- fsxontap in .terraform/modules/fsxontap/Terraform/deploy-fsx-ontap
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

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSxN-Samples/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

<!-- BEGIN_TF_DOCS -->

## Table of Contents
* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Author Information](#author-information)
* [License](#license)

## Introduction

## Prerequisites

### Providers

| Name | Version |
|------|---------|
| aws | n/a |

### Repository Overview

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| fsx_capacity_size_gb | The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608 | `string` | `"1024"` | no |
| fsx_deploy_type | The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1 | `string` | `"SINGLE_AZ_1"` | no |
| fsx_name | The deployed filesystem name | `string` | `"terraform-fsxn"` | no |
| fsx_subnets | The IDs of the subnets fro which the FSxN filesystem will be assigned IP addresses | `map` | <pre>{<br>  "primarysub": "",<br>  "secondarysub": ""<br>}</pre> | no |
| fsx_tput_in_MBps | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096. | `string` | `"256"` | no |
| svm_name | The name of the Storage Virtual Machine | `string` | `"first_svm"` | no |
| tags | Tags to be applied to the resources | `map` | <pre>{<br>  "Name": "terraform-fsxn"<br>}</pre> | no |
| vol_info | Details for the volume creation | `map` | <pre>{<br>  "cooling_period": 31,<br>  "efficiency": true,<br>  "junction_path": "/vol1",<br>  "size_mg": 1024,<br>  "tier_policy_name": "AUTO",<br>  "vol_name": "vol1"<br>}</pre> | no |
| vpc_id | The ID of the VPC in which the FSxN fikesystem should be deployed | `string` | `"vpc-111111111"` | no |

### Outputs

| Name | Description |
|------|-------------|
| my_filesystem_id | The ID of the FSxN Filesystem |
| my_fsx_ontap_security_group_id | The ID of the FSxN Security Group |
| my_svm_id | The ID of the FSxN Storage Virtual Machine |
| my_vol_id | The ID of the ONTAP volume in the File System |

## Usage

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSxN-Samples/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

<!-- END_TF_DOCS -->