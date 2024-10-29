# Deploy DR FSx ONTAP cluster and create SnapMirror relationships from source FSxN

## Introduction
This repository contains a method to take an existing FSxN system and replicate volumes to a new FSx ONTAP instance for disaster recovery or backup purposes.  It leverages both AWS FSx Terraform provider as well as the ONTAP Terraform provider.

## Setup

You will need to define some key characteristics of your destination FSxN cluster to be created, such as deployment type and througput, full list below.  You also will need to define the source SVM and list of volumes to replicate, and replication parameters.

These values can be found in the following variables files: Primary_FSxN_variables.tf and DR_FSxN_variables.tf



## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
