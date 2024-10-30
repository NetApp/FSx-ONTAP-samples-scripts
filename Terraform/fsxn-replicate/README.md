# Deploy DR FSx ONTAP cluster and create SnapMirror relationships from source FSxN

## Introduction
This repository contains a method to take an existing FSxN system and replicate volumes to a new FSx ONTAP instance for disaster recovery or backup purposes.  It leverages both AWS FSx Terraform provider as well as the ONTAP Terraform provider.

## Setup

You will need to define some key characteristics of your destination FSxN cluster to be created, such as deployment type and througput, full list below.  You also will need to define the source SVM and list of volumes to replicate, and replication parameters.

These values can be found in the following variables files: Primary_FSxN_variables.tf and DR_FSxN_variables.tf

## Prerequisites
You have an existing FSx ONTAP system that you want to replicate to a new FSxN system.  There is proper networking connectivy between the source FSxN system and the region/VPC/subnets where the destination FSxN system will be deployed.

SnapMirror replication requires **ICMP** and ports **11104** and **11105**.

## Primary Inputs

| Name                  | Description                                                                                                   | Type           | Default                              | Required |
| --------------------- | ------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------ | :------: |
| prime_hostname        | Hostname or IP address of primary cluster.                                                                    | `string`       |                                      |   Yes    |
| prime_fsxid           | FSx ID of the primary cluster.                                                                                | `string`       |                                      |   Yes    |
| prime_clus_name       | This is the name of the cluster given for ONTAP TF connection profile.  This is a user created value, that can be any string.  It is referenced in many ONTAP TF resources | `string`  |  primary_clus  |   Yes   | 
| prime_svm             | Name of the primary SVM for the volumes that will be replicated.                                              | `string`       |                                      |   Yes    |
| prime_cluster_vserver | Name of the ONTAP cluster vserver for intercluster LIFs in the primary cluster.  Can be found by running `network interface show` on the primary cluster. It will have the format FsxId#################  | `string` |  Yes  |
| prime_aws_region      | AWS region of the primary FSx ONTAP system                                                                    | `string`       |                                      |  Yes     |
| username_pass_secrets_id | Name of the secrets ID in AWS secrets.  The AWS Secret should has format of a key `username` which should be fsxadmin and a key `password` and the password of the FSxN | `string` |   | Yes |
| validate_certs        | Do we validate the cluster certs (true or false)                                                              | `string`       | false                                |  No      |
| list_of_volumes_to_replicate | List of volume names to replicate to the destination FSx ONTAP system                                  | `list(string)`   |                                      |  Yes     |


 




## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
