# Amazon FSx for NetApp ONTAP - Samples & Scripts

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Lint](https://github.com/NetApp/FSx-ONTAP-samples-scripts/actions/workflows/actionlint.yml/badge.svg)](https://github.com/NetApp/FSx-ONTAP-samples-scripts/actions/workflows/actionlint.yml)
[![Code Quality: Terraform](https://github.com/NetApp/FSx-ONTAP-samples-scripts/actions/workflows/terraform.yml/badge.svg)](https://github.com/NetApp/FSx-ONTAP-samples-scripts/actions/workflows/terraform.yml)
[![GitHub stars](https://img.shields.io/github/stars/NetApp/FSx-ONTAP-samples-scripts)](https://github.com/NetApp/FSx-ONTAP-samples-scripts/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/NetApp/FSx-ONTAP-samples-scripts)](https://github.com/NetApp/FSx-ONTAP-samples-scripts/network/members)
[![GitHub contributors](https://img.shields.io/github/contributors/NetApp/FSx-ONTAP-samples-scripts)](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors)

Production-ready code samples, automation scripts, and Infrastructure as Code (IaC) templates for
**[Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/)**. Use these samples alongside the
automation, management, and monitoring that **[NetApp Workload Factory](https://console.workloads.netapp.com)** provides.

---

## Table of Contents

### Infrastructure as Code

Provision, configure, and replicate FSx ONTAP resources using industry-standard IaC tools.

* **[Ansible](/Infrastructure_as_Code/Ansible)**
    * [FSx ONTAP inventory report](/Infrastructure_as_Code/Ansible/fsx_inventory_report) - Generate a report of FSx ONTAP resources in your AWS account.
    * [SnapMirror report](/Infrastructure_as_Code/Ansible/snapmirror_report) - Generate a report of SnapMirror relationships in your AWS account.
    * [Volume Management](/Infrastructure_as_Code/Ansible/Volume_Management) - Automate volume management tasks such as creation, deletion, cloning and managing CIFS shares.
* **[CloudFormation](/Infrastructure_as_Code/CloudFormation)**
    * [Deploy-fsx-ontap](/Infrastructure_as_Code/CloudFormation/deploy-fsx-ontap) - Deploy FSx ONTAP with a single CloudFormation template.
    * [Export FSx for ONTAP Configuration to CloudFormation](/Infrastructure_as_Code/CloudFormation/Export-FSxN-CloudFormation) - Export FSx ONTAP configuration to CloudFormation templates for redeployment.
    * [NetApp-FSxN-Custom-Resources-Samples](/Infrastructure_as_Code/CloudFormation/NetApp-FSxN-Custom-Resources-Samples) - Examples on how to use the NetApp FSxN Custom Resources for CloudFormation.
* **[Terraform](/Infrastructure_as_Code/Terraform)**
    * [Deployment of FSx ONTAP with VPN for File Share Access](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-fileshare-access) - Deploy FSx ONTAP with VPN for file share access.
    * [Deployment of SQL Server on EC2 with FSx ONTAP](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-sqlserver) - Deploy SQL Server on EC2 with FSx ONTAP storage.
    * [FSx ONTAP deployment using Terraform](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap) - Deploy FSx ONTAP using Terraform.
    * [FSx ONTAP Replication](/Infrastructure_as_Code/Terraform/fsxn-replicate) - Replicate FSx ONTAP volumes using Terraform.
    * [Miscellaneous FSx ONTAP resources using Terraform](/Infrastructure_as_Code/Terraform/Miscellaneous) - Additional Terraform examples and helpers.

### EKS

Run stateful Kubernetes workloads on Amazon EKS with FSx ONTAP persistent volumes.

* [Backup-EKS-Applications-with-Trident-Protect](/EKS/Backup-EKS-Applications-with-Trident-Protect) - Backup EKS applications using Trident Protect.
* [EKS applications non-stdout logs collection into ELK](/EKS/EKS-logs-to-ELK) - Collect non-stdout logs from EKS applications into ELK stack.
* [FSx for NetApp ONTAP as persistent storage for EKS](/EKS/FSxN-as-PVC-for-EKS) - Use FSx ONTAP as persistent storage for EKS applications.
* [PV-Migrate-with-Trident-Protect](/EKS/PV-Migrate-with-Trident-Protect) - Migrate persistent volumes in EKS using Trident Protect.

### Management Utilities

Day-2 operational tools for managing FSx ONTAP file systems at scale.

* [Auto Create SnapMirror Relationships](/Management-Utilities/auto_create_sm_relationships) - Automatically create SnapMirror relationships between FSx ONTAP file systems.
* [Auto Set FSxN Auto Grow](/Management-Utilities/auto_set_fsxn_auto_grow) - Automatically set FSx ONTAP auto grow settings for volumes.
* [AWS CLI management scripts for FSx ONTAP](/Management-Utilities/fsx-ontap-aws-cli-scripts) - Management FSxN resources with CLI.
* [FSx ONTAP iscsi volume creation automation for Windows](/Management-Utilities/iscsi-vol-create-and-mount) - Automate FSx ONTAP iSCSI volume creation and mounting on Windows.
* [Rotate AWS Secrets Manager Secret](/Management-Utilities/fsxn-rotate-secret) - Rotate FSxN credentials while keeping an AWS Secrets Manager secret in sync.
* [Warm Performance Tier](/Management-Utilities/warm_performance_tier) - Warm FSx ONTAP volume that has been tiered off to the capacity tier.
* [Workload Factory API Samples](/Management-Utilities/Workload-Factory-API-Samples) - Manage Workload Factory resources using bash shell scripts.

---

## Contributing

We welcome contributions from the community! Please read our [contribution guidelines](CONTRIBUTING.md) before getting started.

Have a great idea? We'd love to hear it! Please email us at [ng-fsxn-github-samples@netapp.com](mailto:ng-fsxn-github-samples@netapp.com).

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
