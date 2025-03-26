# :warning: **NOTICE:**

This repository is no longer being maintain. However, all the code found here has been relocated to a new NetApp managed GitHub repository found here [https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Management-Utilities](https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Management-Utilities). Please refer to that repository for the latest updates. This repository is being left behind purely for historical purposes.

# Management Utilities Overview
This subfolder contains tools that can help you manage your FSx ONTAP file system.

| Tool | Description |
| --- | --- |
| [auto_create_sm_relationships](/Management-Utilities/auto_create_sm_relationships) | This tool will automatically create SnapMirror relationships between two FSx ONTAP file systems. |
| [autto_set_fsxn_auto_grow](/Management-Utilities/auto_set_fsxn_auto_grow) | This tool will automatically set the auto size mode of an FSx for ONTAP volume to 'grow'. |
| [fsx-ontap-aws-cli-scripts](/Management-Utilities/fsx-ontap-aws-cli-scripts) | This repository contains a collection of AWS CLI scripts that can help you manage your FSx ONTAP file system. |
| [fsxn-rotate-secret](/Management-Utilities/fsxn-rotate-secret) | This is a Lambda function that can be used with an AWS Secrets Manager secret to rotate the FSx for ONTAP admin password. |
| [iscsi-vol-create-and-mount](/Management-Utilities/iscsi-vol-create-and-mount) | This tool will create an iSCSI volume on an FSx ONTAP file system and mount it to an EC2 instance running Windows. |
| [warm_performance_tier](/Management-Utilities/warm_performance_tier) | This tool to warm up the performance tier of an FSx ONTAP file system volume. |

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
