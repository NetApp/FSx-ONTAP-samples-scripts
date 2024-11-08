# Deploy DR FSx for ONTAP file system and create SnapMirror relationships from source FSx for ONTAP file system

## Introduction
This repository contains a method to take an existing FSx for ONTAP file system and replicate volumes to a new FSx for ONTAP file system for disaster recovery or backup purposes.  It leverages both AWS FSx Terraform provider as well as the ONTAP Terraform provider.

Note: Currently it supports replicating volumes within a single SVM.

## Setup

### Overview

You will need to define some key characteristics of the destination FSx for ONTAP file system that will be created, such as deployment type and througput, full list below.  You also will need to define the source SVM and list of volumes to replicate, and replication parameters.

These values can be found in the following variables files: Primary_FSxN_variables.tf and DR_FSxN_variables.tf files. The values should be set in the terraform.tfvars file.

### Prerequisites
You have an existing FSx for ONTAP file system that you want to replicate to a new FSx for ONTAP file system.  There is proper networking connectivy between the source FSx for ONTAP file system and the region/VPC/subnets where the destination FSx for ONTAP file system will be deployed.

SnapMirror replication requires **ICMP** and ports **11104** and **11105**.

### Inputs (Primary Cluster)

These variables are to be filled in the terraform.tfvars file, please see instruction below in the Usage section.

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| prime_fsxid           | FSx for ONTAP file system ID of the primary cluster.                                                          | `string`       |                                      |   Yes    |
| prime_svm             | Name of the primary SVM for the volumes that will be replicated.                                              | `string`       |                                      |   Yes    |
| prime_cluster_vserver | Name of the ONTAP cluster vserver for intercluster LIFs in the primary cluster.  Can be found by running `network interface show -services default-intercluster` on the primary cluster. It will have the format FsxId#################  | `string` |    | Yes  |
| prime_aws_region      | AWS region of the primary FSx for ONTAP file system                                                           | `string`       |                                      |  Yes     |
| username_pass_secrets_id | Name of the secrets ID in AWS secrets. The AWS Secret should have a format of a key `username`, which should have a value of `fsxadmin,` and another key `password` with its value set to the password of the FSxN. *Note*: The secret must be in the same region as the FSx for ONTAP file system it is associated with. | `string` |   | Yes |
| validate_certs        | When connecting to an FSx for ONTAP file system, should Terraform validate the SSL certificate (true or false)? This should be set to `false` if you are using the default self-signed SSL certificate.  | `string`       | false                                |  No      |
| list_of_volumes_to_replicate | List of volume names to replicate to the destination FSx for ONTAP file system                         | `list(string)`   |                                      |  Yes     |


### Inputs (DR Cluster)

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| dr_aws_region         | AWS region where you want the Secondary(DR) FSx for ONTAP file system to be deployed.                         | `string`       |                                      |   Yes    |
| dr_fsx_name           | The name to assign to the destination FSx for ONTAP file system that will be created.                         | `string`       |                                      |   Yes    |
| dr_fsx_deploy_type    | The file system deploment type. Supported values are 'MULTI_AZ_1', 'SINGLE_AZ_1', 'MULTI_AZ_2', and 'SINGLE_AZ_2'. MULTI_AZ_1 and SINGLE_AZ_1 are Gen 1. MULTI_AZ_2 and SINGLE_AZ_2 are Gen 2. | `string` | SINGLE_AZ_1 | Yes |
| dr_fsx_subnets        | The primary subnet ID, and secondary subnet ID if you are deploying in a Multi AZ environment, file system will be accessible from. For MULTI_AZ deployment types both subnets are required. For SINGLE_AZ deployment type, only the primary subnet is used. | `map(any)` |     | Yes |
| dr_fsx_capacity_size_gb | The storage capacity in GiBs of the FSx for ONTAP file system. Valid values between 1024 (1 TiB) and 1048576 (1 PiB). Gen 1 deployment types are limited to 192 TiB. Gen 2 Multi AZ is limited to 512 TiB. Gen 2 Single AZ is limited to 1 PiB. The sizing should take into account the size of the volumes you plan to replicate and the tiering policy of the volumes. | `number` | 1024 | Yes |
| dr_fsx_tput_in_MBps   | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096 for Gen 1, and 384, 768, 1536, 3072 and 6144 for Gen 2. | `string` | 128 | Yes |
| dr_ha_pairs           | The number of HA pairs in the file system. Valid values are from 1 through 12. Only single AZ Gen 2 deployment type supports more than 1 HA pair. | `number` | 1 | Yes |
| dr_endpoint_ip_address_range | The IP address range that the FSx for ONTAP file system will be accessible from. This is only used for Multi AZ deployment types and must be left a null for Single AZ deployment types. | `string` | null | No |
| dr_route_table_ids    | An array of routing table IDs that will be modified to allow access to the FSx for ONTAP file system. This is only used for Multi AZ deployment types and must be left as null for Single AZ deployment types. | `list(string)` | [] | Only required for Multi-AZ |
| dr_disk_iops_configuration | The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provisioned) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVISIONED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in double quotes) and 'iops=number' where number is between 1 and 160000. | `map(any)` | {} | No |
| dr_tags               | Tags to be applied to the FSx for ONTAP file system. The format is '{Name1 = value, Name2 = value}' where value should be enclosed in double quotes. | `map(any)` | {} | No |
| dr_maintenance_start_time | The preferred start time to perform weekly maintenance, in UTC time zone. The format is 'D:HH:MM' format. D is the day of the week, where 1=Monday and 7=Sunday. | `string` | 7:00:00 | No |
| dr_svm_name           | The name of the Storage Virtual Machine that will house the replicated volumes. | `string` | fsx_dr   | Yes |
| dr_root_vol_sec_style | Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume. | `string` | UNIX | Yes |
| dr_username_pass_secrets_id | Name of the secrets ID in AWS secrets. The AWS Secret should have a format of a key `username`, which should have a value of `fsxadmin,` and another key `password` with its value set to the password of the FSxN. *Note*: The secret must be in the same region as the FSx for ONTAP file system it is associated with. | `string` |  | Yes |
| dr_vpc_id             | The VPC ID where the DR FSx for ONTAP file system (and security group if this option is selected) will be created. | `string` |  | Yes |
| dr_snapmirror_policy_name | Name of snamirror policy to create.                                                                            | `string` |  | Yes |
| dr_transfer_schedule  | The schedule used to update asynchronous relationships.                                                            | `string` | hourly | No |
| dr_retention          | Rules for Snapshot copy retention. See [Retention Schema](https://registry.terraform.io/providers/NetApp/netapp-ontap/latest/docs/resources/snapmirror_policy_resource#retention) for more information.  | `string` | [{ "label": "weekly", "count": 4 }, { "label": "daily", "count": 7 }] | No |
## Inputs (Security Group - DR Cluster)

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| dr_create_sg          | Determines whether the Security Group should be created as part of this deployment or not.                    | `bool`         |  true                                |   Yes    |
| dr_security_group_ids | If you are not creating the security group, provide a list of IDs of security groups to be used.              | `list(string)` |  []                                  |   No     |
| dr_security_group_name_prefix | The prefix to the security group name that will be created.                                           | `string`       |  fsxn-sg                             |   No     |
| dr_cidr_for_sg        | The cidr block to be used for the created security ingress rules. Set to an empty string if you want to use the source_sg_id as the source. | `string`       |  10.0.0.0/8                          |   No     |
| dr_source_sg_id       | The ID of the security group to allow access to the FSx for ONTAP file system. Set to an empty string if you want to use the cidr_for_sg as the source. | `string` |           |   No     |

## Usage

#### 1. Clone the repository

In your server's terminal, navigate to the location where you wish to store this Terraform repository, and clone the repository using your preferred authentication type. In this example we are using HTTPS clone:

```shell
git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts
```

#### 2. Navigate to the directory

```shell
cd FSx-ONTAP-samples-scripts/Terraform/fsxn-replicate
```

#### 3. Initialize Terraform

This directory represents a standalone Terraform module. Run the following command to initialize the module and install all dependencies:

```shell
terraform init
```

A succesfull initialization should display the following output:

```

Initializing the backend...
Initializing modules...

Initializing provider plugins...
- Reusing previous version of netapp/netapp-ontap from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed netapp/netapp-ontap v1.1.4
- Using previously-installed hashicorp/aws v5.69.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

```

You can see that Terraform recognizes the modules required by our configuration: `hashicorp/aws` and `hashicorpt/netapp-ontap`.

#### 4. Create Variables Values

- Copy or Rename the file **`terraform.sample.tfvars`** to **`terraform.tfvars`**

- Open the **`terraform.tfvars`** file in your preferred text editor. Update the values of the variables to match your preferences and save the file. This will ensure that the Terraform code deploys resources according to your specifications.

- Set the parameters in terraform.tfvars

  ##### Sample file

  ***

  ```ini
    # Primary FSxN variables
    prime_hostname                = "<cluster mgmt ip address>"
    prime_fsxid                   = "fs-xxxxxxxxxxxxxxxxx"
    prime_svm                     = "fsx"
    prime_cluster_vserver         = "FsxIdxxxxxxxxxxxxxxxx"
    prime_aws_region              = "us-west-2"
    username_pass_secrets_id      = "<Name of AWS secret>"
    list_of_volumes_to_replicate  = ["vol1", "vol2", "vol3"]

    # DR FSxN variables
    dr_aws_region                 = "us-west-2"
    dr_fsx_name                   = "terraform-dr-fsxn"
    dr_fsx_subnets                = {
                                       "primarysub" = "subnet-11111111"
                                       "secondarysub" = "subnet-33333333"
                                    }
    dr_svm_name                   = "fsx_dr"
    dr_security_group_name_prefix = "fsxn-sg"
    dr_vpc_id                     = "vpc-xxxxxxxx"
    dr_username_pass_secrets_id   = "<Name of AWS secret>"
    dr_snapmirror_policy_name     = "<Name of Policy to create>"
  ```

> [!IMPORTANT]
> **Make sure to replace the values with ones that match your AWS environment and needs.**

#### 5. Create a Terraform plan

Run the following command to create an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:

```shell
terraform plan
```

Ensure that the proposed changes match what you expected before you apply the changes!

#### 6. Apply the Terraform plan

Run the following command to execute the Terrafom code and apply the changes proposed in the `plan` step:

```shell
terraform apply
```

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
