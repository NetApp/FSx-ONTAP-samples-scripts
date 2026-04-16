# Amazon FSx for NetApp ONTAP — Samples & Scripts

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

## Quick Navigation

| Track | Focus | Samples |
|:------|:------|:-------:|
| [Infrastructure as Code](/Infrastructure_as_Code) | Terraform, CloudFormation & Ansible templates for provisioning and configuring FSx ONTAP resources | 11 |
| [EKS](/EKS) | Persistent storage for Kubernetes with Trident Protect, PV migration & log collection | 4 |
| [Management Utilities](/Management-Utilities) | Day-2 operations — SnapMirror, secrets rotation, auto-grow, iSCSI, reporting & more | 9 |
| [Monitoring](/Monitoring) | CloudWatch dashboards, alarms, LUN metrics, Harvest/Grafana & ONTAP service health | 7 |

---

## Getting Started

1. **Browse** the catalog below or use the Quick Navigation table above to find a sample.
2. **Clone** this repository:
   ```bash
   git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts.git
   ```
3. **Navigate** into the sample directory and follow its `README.md` for prerequisites and usage.
4. **Contribute** — we welcome PRs! Read our [contribution guidelines](CONTRIBUTING.md) first.

Have a great idea? We'd love to hear it! Email us at [ng-fsxn-github-samples@netapp.com](mailto:ng-fsxn-github-samples@netapp.com).

---

## Sample Catalog

### Infrastructure as Code

Provision, configure, and replicate FSx ONTAP resources using industry-standard IaC tools.

* **[Ansible](/Infrastructure_as_Code/Ansible)**
    * [FSx ONTAP inventory report](/Infrastructure_as_Code/Ansible/fsx_inventory_report) — Generate a complete inventory of your FSx ONTAP resources
    * [SnapMirror report](/Infrastructure_as_Code/Ansible/snapmirror_report) — Report on SnapMirror relationship status
    * [Volume Management](/Infrastructure_as_Code/Ansible/Volume_Management) — Create, modify, and delete volumes
* **[CloudFormation](/Infrastructure_as_Code/CloudFormation)**
    * [Deploy FSx ONTAP](/Infrastructure_as_Code/CloudFormation/deploy-fsx-ontap) — One-click FSx ONTAP deployment stack
    * [Export FSx ONTAP Configuration to CloudFormation](/Infrastructure_as_Code/CloudFormation/Export-FSxN-CloudFormation) — Reverse-engineer existing resources into templates
    * [Custom Resources Samples](/Infrastructure_as_Code/CloudFormation/NetApp-FSxN-Custom-Resources-Samples) — Lambda-backed custom resources for advanced provisioning
* **[Terraform](/Infrastructure_as_Code/Terraform)**
    * [FSx ONTAP deployment](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap) — Core Terraform module for FSx ONTAP
    * [FSx ONTAP with VPN for File Share Access](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-fileshare-access) — Secure file share access over VPN
    * [SQL Server on EC2 with FSx ONTAP](/Infrastructure_as_Code/Terraform/deploy-fsx-ontap-sqlserver) — End-to-end SQL Server deployment with FSx ONTAP storage
    * [FSx ONTAP Replication](/Infrastructure_as_Code/Terraform/fsxn-replicate) — SnapMirror replication via Terraform
    * [Miscellaneous Terraform resources](/Infrastructure_as_Code/Terraform/Miscellaneous) — Additional Terraform examples and helpers

### EKS

Run stateful Kubernetes workloads on Amazon EKS with FSx ONTAP persistent volumes.

* [Backup EKS Applications with Trident Protect](/EKS/Backup-EKS-Applications-with-Trident-Protect) — Backup and restore PVCs using Trident Protect
* [EKS non-stdout logs collection into ELK](/EKS/EKS-logs-to-ELK) — Shared FSx ONTAP storage for non-standard log collection
* [FSx for NetApp ONTAP as persistent storage for EKS](/EKS/FSxN-as-PVC-for-EKS) — Sandbox environment for FSx ONTAP PVC integration
* [PV Migrate with Trident Protect](/EKS/PV-Migrate-with-Trident-Protect) — Migrate persistent volumes between clusters

### Management Utilities

Day-2 operational tools for managing FSx ONTAP file systems at scale.

* [Auto Create SnapMirror Relationships](/Management-Utilities/auto_create_sm_relationships) — Automatically create SnapMirror relationships between file systems
* [Auto Set FSxN Auto Grow](/Management-Utilities/auto_set_fsxn_auto_grow) — Automatically enable volume auto-grow
* [AWS CLI Management Scripts](/Management-Utilities/fsx-ontap-aws-cli-scripts) — Collection of AWS CLI scripts for FSx ONTAP operations
* [EC2 User Data iSCSI Create & Mount](/Management-Utilities/ec2-user-data-iscsi-create-and-mount) — Launch EC2 instances with auto-provisioned iSCSI volumes
* [FSxN Report](/Management-Utilities/FSxN-Report) — Generate reports of all FSx ONTAP file systems, volumes, and SVMs
* [iSCSI Volume Creation for Windows](/Management-Utilities/iscsi-vol-create-and-mount) — Create iSCSI volumes and mount to Windows EC2 instances
* [Rotate AWS Secrets Manager Secret](/Management-Utilities/fsxn-rotate-secret) — Lambda function for FSx ONTAP admin password rotation
* [Warm Performance Tier](/Management-Utilities/warm_performance_tier) — Warm up the performance tier of an FSx ONTAP volume
* [Workload Factory API Samples](/Management-Utilities/Workload-Factory-API-Samples) — Bash scripts demonstrating Workload Factory API usage

### Monitoring

> [!NOTE]
> Active monitoring development has moved to **[NetApp/FSx-ONTAP-monitoring](https://github.com/NetApp/FSx-ONTAP-monitoring)**.
> The samples below remain functional but new features land in the dedicated monitoring repository.

* [Automatically Add CloudWatch Alarms](/Monitoring/auto-add-cw-alarms) — Auto-create alarms for storage, CPU, and volume utilization
* [CloudWatch Dashboard for FSx ONTAP](/Monitoring/CloudWatch-FSx) — Pre-built CloudWatch dashboard for FSx ONTAP metrics
* [Export LUN Metrics to CloudWatch](/Monitoring/LUN-monitoring) — Push LUN metrics to CloudWatch with a dashboard
* [Ingest NAS Audit Logs into CloudWatch](/Monitoring/ingest_nas_audit_logs_into_cloudwatch) — Stream NAS audit logs to CloudWatch
* [Monitor FSx ONTAP with Harvest on EC2](/Monitoring/monitor_fsxn_with_harvest_on_ec2) — Harvest + Prometheus + Grafana on EC2
* [Monitor FSx ONTAP with Harvest on EKS](/Monitoring/monitor_fsxn_with_harvest_on_eks) — Harvest + Prometheus + Grafana on EKS
* [Monitor ONTAP Services](/Monitoring/monitor-ontap-services) — Lambda-based monitoring with SNS alerts for EMS, SnapMirror, quotas & health

---

## Related Resources

| Resource | Link |
|:---------|:-----|
| AWS FSx for NetApp ONTAP documentation | [docs.aws.amazon.com](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html) |
| NetApp Workload Factory | [console.workloads.netapp.com](https://console.workloads.netapp.com) |
| FSx ONTAP Monitoring (dedicated repo) | [NetApp/FSx-ONTAP-monitoring](https://github.com/NetApp/FSx-ONTAP-monitoring) |
| NetApp BlueXP | [bluexp.netapp.com](https://bluexp.netapp.com) |

---

## Contributing

We welcome contributions from the community! Please read our [contribution guidelines](CONTRIBUTING.md) before getting started.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
