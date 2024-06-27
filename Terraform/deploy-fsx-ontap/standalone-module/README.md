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
* **main.tf** - The main set of configuration for this terraform sample
* **variables.tf** - Contains the variable definitions and assignments for this sample. Exported values will override any of the variables in this file. 
* **output.tf** - Contains output declarations of the resources created by this Terraform module. Terraform stores output values in the configuration's state file

### What to expect
Running this terraform sample will result the following:
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
    * Multi AZ deployment type
    * 128Mbps of throughput capacity 

* Create a Storage Virtual Maching (SVM) in this new file-system named "_first_svm_"
* Create a new FlexVol volume in this SVM named "_vol1_" with the following configuration parameters:
    * Size of 1024Mb
    * Storage efficiencies mechanism enabled
    * Auto tiering policy with 31 cooling days
    * post-delete backup disabled 

> [!NOTE]
> Even though this Terraform code is set up to use AWS SecretsManager to retrieve the FSxN password, it will store the password in its `state database`. Therefore, it is assumed you have properly secured that database so that unauthorized personal can't access the password.

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

A succesfull initialization should display the following output:
```shell

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.25.0

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

- Open the **`variables.tf`** file in your preferred text editor. Update the values of the variables to match your
preferences and save the file. This will ensure that the Terraform code deploys resources according to your specifications.

**Make sure to replace the values with ones that match your AWS environment and needs.**
Modify the remaining optional variables (e.g. defining AD) in the **`main.tf`** file and remove commenting
where needed according to the explanations in-line.

### 5. Update Security Group
A default security group is defined in the "security_groups.tf" file. At the top of
that file you can see where you can specify either a CIDR block or a security group ID
to allow access to the FSxN file system. Do not specify both, as it will cause
the terraform deployment to fail.

If you decide you don't want to use the security group, you can either delete the security_groups.tf file,
or just rename it such that it doesn't end with ".tf" (e.g. security_groups.tf.kep). You will also need
to update the `security_group_ids  = [aws_security_group.fsx_sg.id]` line in the main.tf file
to reference the security group(s) you want to use.

### 6. Create a Terraform plan
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

## Terraform Overview

### Providers

| Name | Version |
|------|---------|
| aws | 5.25.0 |

### Inputs

| Name | Description | Type | Default | Must be changed |
|------|-------------|------|---------|-----------------|
| aws_secretsmanager_region | The AWS region where the secret is stored. | `string` | `"us-east-2"` | No |
| fsx_capacity_size_gb | The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608. | `number` | `1024` | No |
| fsx_deploy_type | The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1 | `string` | `"MULTI_AZ_1"` | No |
| fsx_name | The deployed filesystem name | `string` | `"terraform-fsxn"` | No |
| fsx_region | The AWS region where the FSxN file system to be deployed. | `string` | `"us-west-2"` | No |
| fsx_secret_name | The name of the AWS SecretManager secret that holds the ONTAP administrative password for the fsxadmin user that you can use to administer your file system using the ONTAP CLI and REST API. | `string` | `"fsx_secret"` | Yes |
| fsx_subnets | A list of IDs for the subnets that the file system will be accessible from. Up to 2 subnets can be provided. | `map(any)` | <pre>{<br>  "primarysub": "subnet-22222222",<br>  "secondarysub": "subnet-22222222"<br>}</pre> | Yes |
| fsx_tput_in_MBps | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096. | `number` | `128` | No |
| svm_name | The name of the Storage Virtual Machine | `string` | `"first_svm"` | No |
| vol_info | Details for the volume creation | `map(any)` | <pre>{<br>  "cooling_period": 31,<br>  "efficiency": true,<br>  "junction_path": "/vol1",<br>  "size_mg": 1024,<br>  "tier_policy_name": "AUTO",<br>  "vol_name": "vol1"<br>}</pre> | No |
| vpc_id | The ID of the VPC in which the FSxN fikesystem should be deployed | `string` | `"vpc-11111111"` | Yes |

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
