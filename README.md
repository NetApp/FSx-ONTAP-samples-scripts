# FSx-ONTAP-samples-scripts

FSx for NetApp ONTAP is an AWS service providing a comprehensive set of advanced storage features purposely
built to maximize cost performance, resilience, and accessibility in business-critical workloads.

## Overview

This GitHub repository contains comprehensive code samples and automation scripts for FSx for Netapp ONTAP operations,
promoting the use of Infrastructure as Code (IAC) tools and encouraging developers to extend the product's
functionalities through code. The samples here go alongside the automation, management and monitoring that
[Workload Factory](https://console.workloads.netapp.com) provides.

We welcome contributions from the community! Please read our [contribution guidelines](CONTRIBUTING.md) before getting started.

Have a great idea? We'd love to hear it! Please email us at [ng-fsxn-github-samples@netapp.com](mailto:ng-fsxn-github-samples@netapp.com).

## Table of Contents

* [Infrastructure as Code](/Infrastructure_as_Code)
    * [Ansible](/Infrastructure_as_Code/Ansible)
        * [FSx ONTAP inventory report](/Infrastructure_as_Code/Ansible/fsx_inventory_report)
        * [SnapMirror report](/Infrastructure_as_Code/Ansible/snapmirror_report)
        * [Volume Management](/Infrastructure_as_Code/Ansible/Volume_Management)
    * [CloudFormation](/Infrastructure_as_Code/CloudFormation)
        * [NetApp-FSxN-Custom-Resources-Samples](/Infrastructure_as_Code/CloudFormation/NetApp-FSxN-Custom-Resources-Samples)
        * [deploy-fsx-ontap](/Infrastructure_as_Code/CloudFormation/deploy-fsx-ontap)
    * [Terraform](/Infrastructure_as_Code/Terraform)
        * [FSx ONTAP deployment using Terraform](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap)
        * [FSx ONTAP Replication](/Infrastructure_as_Code/Terraform/fsxn-replicate)
        * [Deployment of SQL Server on EC2 with FSx ONTAP](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-sqlserver)
        * [Deployment of FSx ONTAP with VPN for File Share Access](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-fileshare-access)
* [EKS](/EKS)
    * [Backup-EKS-Applications-with-Trident-Protect](/EKS/Backup-EKS-Applications-with-Trident-Protect)
    * [FSx for NetApp ONTAP as persistent storage for EKS](/EKS/FSxN-as-PVC-for-EKS)
    * [EKS applications non-stdout logs collection into ELK](/EKS/EKS-logs-to-ELK)
    * [PV-Migrate-with-Trident-Protect](/EKS/PV-Migrate-with-Trident-Protect)
* [Management Utilities](/Management-Utilities)
    * [Auto Create SnapMirror Relationships](/Management-Utilities/auto_create_sm_relationships)
    * [Auto Set FSxN Auto Grow](/Management-Utilities/auto_set_fsxn_auto_grow)
    * [AWS CLI management scripts for FSx ONTAP](/Management-Utilities/fsx-ontap-aws-cli-scripts)
    * [Rotate AWS Secrets Manager Secret](/Management-Utilities/fsxn-rotate-secret)
    * [FSx ONTAP iscsi volume creation automation for Windows](/Management-Utilities/iscsi-vol-create-and-mount)
    * [Warm Performance Tier](/Management-Utilities/warm_performance_tier)
    * [Workload Factory API Samples](/Management-Utilities/Workload-Factory-API-Samples)
* [Monitoring](/Monitoring)
    * [CloudWatch Dashboard for FSx for ONTAP](/Monitoring/CloudWatch-FSx)
    * [Export LUN metrics from an FSx ONTAP to Amazon CloudWatch](/Monitoring/LUN-monitoring)
    * [Automatically Add CloudWatch Alarms for FSx Resources](/Monitoring/auto-add-cw-alarms)
    * [Ingest NAS audit logs into CloudWatch](/Monitoring/ingest_nas_audit_logs_into_cloudwatch)
    * [Monitor ONTAP metrics from FSx ONTAP using python Lambda function](/Monitoring/monitor-ontap-services)
    * [Monitor FSx for ONTAP with Harvest on EKS](/Monitoring/monitor_fsxn_with_harvest_on_eks)

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
