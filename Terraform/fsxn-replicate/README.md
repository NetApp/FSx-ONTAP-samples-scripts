# Deploy DR FSx ONTAP cluster and create SnapMirror relationships from source FSxN

## Introduction
This repository contains a method to take an existing FSxN system and replicate volumes to a new FSx ONTAP instance for disaster recovery or backup purposes.  It leverages both AWS FSx Terraform provider as well as the ONTAP Terraform provider.

## Setup

You will need to define some key characteristics of the destination FSxN cluster that will be created, such as deployment type and througput, full list below.  You also will need to define the source SVM and list of volumes to replicate, and replication parameters.

These values can be found in the following variables files: Primary_FSxN_variables.tf and DR_FSxN_variables.tf

## Prerequisites
You have an existing FSx ONTAP system that you want to replicate to a new FSxN system.  There is proper networking connectivy between the source FSxN system and the region/VPC/subnets where the destination FSxN system will be deployed.

SnapMirror replication requires **ICMP** and ports **11104** and **11105**.

## Inputs (Primary Cluster)

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| prime_hostname        | Hostname or IP address of primary cluster.                                                                    | `string`       |                                      |   Yes    |
| prime_fsxid           | FSx ID of the primary cluster.                                                                                | `string`       |                                      |   Yes    |
| prime_clus_name       | This is the name of the cluster given for ONTAP TF connection profile.  This is a user created value, that can be any string.  It is referenced in many ONTAP TF resources | `string`  |  primary_clus  |   Yes   | 
| prime_svm             | Name of the primary SVM for the volumes that will be replicated.                                              | `string`       |                                      |   Yes    |
| prime_cluster_vserver | Name of the ONTAP cluster vserver for intercluster LIFs in the primary cluster.  Can be found by running `network interface show` on the primary cluster. It will have the format FsxId#################  | `string` |  Yes  |
| prime_aws_region      | AWS region of the primary FSx ONTAP system                                                                    | `string`       |                                      |  Yes     |
| username_pass_secrets_id | Name of the secrets ID in AWS secrets.  The AWS Secret should has format of a key `username` which should be fsxadmin and a key `password` and the password of the FSxN | `string` |   | Yes |
| validate_certs        | When connecting to ONTAP do we validate the cluster certs (true or false).                                                              | `string`       | false                                |  No      |
| list_of_volumes_to_replicate | List of volume names to replicate to the destination FSx ONTAP system                                  | `list(string)`   |                                      |  Yes     |
## Inputs (DR Cluster)

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| dr_aws_region         | AWS regionfor the Secondary(DR) ONTAP system.                                                                 | `string`       |                                      |   Yes    |
| dr_fsx_name           | The name to assign to the destination FSxN file system that will be created.                                  | `string`       |                                      |   Yes    |
| dr_clus_name          | This is the name of the cluster given for ONTAP TF connection profile.  This is a user created value, that can be any string.  It is referenced in many ONTAP TF resources | `string` | Yes |
| dr_fsx_deploy_type    | The file system deployment type. Supported values are 'MULTI_AZ_1', 'SINGLE_AZ_1', 'MULTI_AZ_2', and 'SINGLE_AZ_2'. MULTI_AZ_1 and SINGLE_AZ_1 are Gen 1. MULTI_AZ_2 and SINGLE_AZ_2 are Gen 2. | SINGLE_AZ_1 | Yes |
| dr_fsx_subnets        | The primary subnet ID, and secondary subnet ID if you are deploying in a Multi AZ environment, file system will be accessible from. For MULTI_AZ deployment types both subnets are required. For SINGLE_AZ deployment type, only the primary subnet is used. `map(any)` |     | Yes |
| dr_fsx_capacity_size_gb | The storage capacity in GiBs of the FSxN file system. Valid values between 1024 (1 TiB) and 1048576 (1 PiB). Gen 1 deployment types are limited to 192 TiB. Gen 2 Multi AZ is limited to 512 TiB. Gen 2 Single AZ is limited to 1 PiB. The sizing should take into account the size of the volumes you plan to replicate and the tiering policy of the volumes. | `number` | 1024 | Yes |
| dr_fsx_tput_in_MBps   | The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096 for Gen 1, and 384, 768, 1536, 3072 and 6144 for Gen 2. | `string` | 128 | Yes |
| dr_ha_pairs           | The number of HA pairs in the file system. Valid values are from 1 through 12. Only single AZ Gen 2 deployment type supports more than 1 HA pair. | `number` | 1 | Yes |
| dr_endpoint_ip_address_range | The IP address range that the FSxN file system will be accessible from. This is only used for Multi AZ deployment types and must be left a null for Single AZ deployment types. | `string` | null | No |
| dr_route_table_ids    | An array of routing table IDs that will be modified to allow access to the FSxN file system. This is only used for Multi AZ deployment types and must be left as null for Single AZ deployment types. | `list(string)` | [] | Only required for Multi-AZ |
| dr_disk_iops_configuration | The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provisioned) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVISIONED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in double quotes) and 'iops=number' where number is between 1 and 160000. | `map(any)` | {} | No |
| dr_tags               | Tags to be applied to the FSxN file system. The format is '{Name1 = value, Name2 = value}' where value should be enclosed in double quotes. | `map(any)` | {} | No |
| dr_maintenance_start_time | The preferred start time to perform weekly maintenance, in UTC time zone. The format is 'D:HH:MM' format. D is the day of the week, where 1=Monday and 7=Sunday. | `string` | 7:00:00 | No |
| dr_svm_name           | The name of the Storage Virtual Machine that will house the replicated volumes. | `string` |   | Yes |
| dr_root_vol_sec_style | Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume. | `string` | UNIX | Yes |
| dr_username_pass_secrets_id | Name of the secrets ID in AWS secrets.  The AWS Secret should has format of a key `username` where the value should be fsxadmin and a key `password` with the value being the password to be assigned to the destination FSxN filesystem. | `string` |  | Yes |




## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
