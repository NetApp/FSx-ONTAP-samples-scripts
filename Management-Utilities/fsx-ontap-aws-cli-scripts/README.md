# FSxN Convenience Scripts
This folder contains sample scripts that are designed to help you use FSxN from
a command line. Most of the scripts are written in Bash, intended to be run either from
a UNIX based O/S (e.g. Linux, MacOS, FreeBSD), or from a Microsoft Windows based system with a
Windows Subsystem for Linux (WSL) based Linux distribution installed.

## Preparation
Before running the UNIX based scripts, make sure the following package is installed:

* jq  - lightweight and flexible command-line JSON processor
* aws-cli - Command Line Interface for AWS

## Summary of the convenience scripts

| Script                  | Description     |
|:------------------------|:----------------|
|create_fsxn_filesystem   | Creates a new FSx for NetApp ONTAP file-system |
|create_fsxn_svm          | Creates a new Storage Virtual Server (svm) in a soecific FSx ONTAP filesystem |
|create_fsxn_volume       | Creates a new volume under a specified SVM. |
|list_fsx_filesystems     | List all the FSx for NetApp ONTAP filesystems that the user has access to. |
|list_fsx_filesystems.ps1 | List all the FSx for NetApp ONTAP filesystems that the user has access to, written in PowerShell. |
|list_fsxn_volumes        | List all the FSx for NetApp ONTAP volumes that the user has access to. |
|list_fsxn_svms           | List all the storage virtual machines that the user access to. |
|list_aws_subnets         | List all the aws subnets. |
|list_aws_vpcs            | List all the aws vpcs. |
|delete_fsxn_filesystem   | Deletes an FSx for NetApp ONTAP filesystem. |
|delete_fsxn_svm          | Deletes an svm. |
|delete_fsxn_volume       | Deletes a volume. |


## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
