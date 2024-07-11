# FSx-ONTAP-samples-scripts

FSx for NetApp ONTAP is an AWS service providing a comprehensive set of advanced storage features purposely built to maximize cost performance, resilience, and accessibility in business-critical workloads.

## Overview

This GitHub repository contains comprehensive code samples and automation scripts for FSx for Netapp ONTAP operations, promoting the use of Infrastructure as Code (IAC) tools and encouraging developers to extend the product's functionalities through code.

We welcome contributions from the community! Please read our [contribution guidelines](CONTRIBUTING.md) before getting started.

Have a great idea? We'd love to hear it! Please share it via the Discussions tab under the Ideas category.

## Table of Contents

* [EKS](/EKS)
    * [FSx for NetApp ONTAP as persistent storage for EKS](/EKS/FSxN-as-PVC-for-EKS)
* [Management Utilities](/Management-Utilities)
    * [Auto Create SnapMirror Relationships](/Management-Utilities/auto_create_sm_relationships)
    * [Auto Set FSxN Auto Grow](/Management-Utilities/auto_set_fsxn_auto_grow)
    * [AWS CLI management scripts for FSx ONTAP](/Management-Utilities/fsx-ontap-aws-cli-scripts)
    * [FSx ONTAP iscsi volume creation automation for Windows](/Management-Utilities/iscsi-vol-create-and-mount)
* [Monitoring](/Monitoring)
    * [Export LUN metrics from an FSx ONTAP to Amazon CloudWatch](/Monitoring/LUN-monitoring)
    * [Monitor ONTAP metrics from FSx ONTAP using python Lambda function](/Monitoring/monitor-ontap-services)
* [Solutions](/Solutions)
    * [k8s applications non-stdout logs collection into ELK](/Solutions/EKS-logs-to-ELK)
* [Terraform](/Terraform)
    * [FSx ONTAP deployment using Terraform](/Terraform/deploy-fsx-ontap)
    * [Deployment of SQL Server on EC2 with FSx ONTAP](/Terraform/deploy-fsx-ontap-sqlserver)
    * [Deployment of FSx ONTAP with VPN for File Share Access](/Terraform/deploy-fsx-ontap-fileshare-access)

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
