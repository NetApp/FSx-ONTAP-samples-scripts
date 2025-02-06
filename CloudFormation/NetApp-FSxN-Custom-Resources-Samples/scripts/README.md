# Support Scripts

## Description
This folder mostly contains scripts that can be used to drive the CloudFormation templates in the folder above.
There are also a couple scripts that can be used to help enable the NetApp FSxN CloudFormation extensions.

| Script | Description |
| ------ | ----------- |
|create_SM_relationship| This script will deploy a CloudFormation stack that creates a SnapMirror relationship between two volumes. Can be be used with both the create_sm_with_peering.yaml create_sm_without_peering.yaml CloudFormation templates. |
|create_clone| This script will deploy a CloudFormation stack that creates a clone of a volume. It is designed to be used with the create_clone.yaml CloudFormation template|
|create_export_policy| This script will deploy a CloudFormation stack that creates an export policy. It is designed to be used with the create_export_policy.yaml CloudFormation template|
|create_snapshot| This script will deploy a CloudFormation stack that creates a snapshot of a volume. It is designed to be used with the create_snapshot.yaml CloudFormation template|
|create_volume| This script will deploy a CloudFormation stack that creates a FSx for ONTAP volume. It is designed to be used with the create_volume.yaml CloudFormation template |
|activate_extensions| This script will activate all the NetApp FSxN CloudFormation extensions in the AWS account for a specific region.|
|deactivate_extensions | This script will deactivate all the NetApp FSxN CloudFormation extensions in the AWS account for a specific region.|
|deploy_link | This script will use CloudFormation to deploy a Workload Factory Link.|
|createClone.py | This is a Python script that will create a clone of a volume using boto to deploy a CloudFormation stack that creates a clone.|

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2025 NetApp, Inc. All Rights Reserved.
