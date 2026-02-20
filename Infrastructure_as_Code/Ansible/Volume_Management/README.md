# Ansible Volume Management samples
This folder contains to Ansible playbooks that can be used to manage volumes within a FSx for ONTAP file system.

They have been configured to use the new `use_lambda` feature that allows it to leverage an Workload Factory Link
to issue the API calls to the FSx for ONTAP file system which alleviate the requirement of the Ansible control
node to have network connectivity to the FSx for ONTAP file system. For more information on how to set up a
Workload Factory Link, please refer to the [NetApp Workload Factory documentation](https://docs.netapp.com/us-en/workload-fsx-ontap/links-overview.html).

The list of playbooks included in this folder is as follows:
- create\_volume.yaml
- delete\_volume.yaml
- create\_snapshot.yaml
- delete\_snapshot.yaml

## Requirements
- Ansible 2.9 or later. Installation instructions can be found [here](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- NetApp ONTAP Ansible collection.
- AWS Ansible collection.
- An AWS secret with the credentials necessary to run the required volume APIs against the FSx for ONTAP file system. The required format of the secret is described below.

## Configuration
Each playbook requires various variables to be set in order to run.
| Variable | Used By Playbook | Required | Default | Description |
|:-------- |:----------------:|:--------:|:-------:|:-----------|
| volume\_name| All | Yes | None | The name of the volume you want to act one.|
| volume\_size| create\_volume | Yes | None | The size, in MiBs, of the volume to create.|
| vserver    | All | Yes | None | The name of the vserver where the volume resides.|
| fsxn\_hostname| All | Yes | None | The hostname or IP address of the FSxN where the volume resides.|
| lambda\_function\_name| All | No | None | The name of the Workload Factory Link to use when issuing API calls to the FSx for ONTAP file system.| 
| aws\_region | All | No | None | The AWS region where the Link lambda function resides.|
| secret\_name | Yes | All | The name of the AWS secret that contains the credentials to authenticate with the FSx for ONTAP file system.|
| snapshot\_name | create\_snapshot | Yes | None | The name of the snapshot to create.|
| security\_style | create\_volume | No | UNIX | The security style to use when creating the volume. Valid options are UNIX or NTFS.|
| aggr | create\_volume | No | aggr1 | The name of the aggregate to create the volume on.|
| volume\_type | create\_volume | No | RW | The type of volume to create. Valid options are RW and DP.|
| junction\_path | create\_volume | No | `/<volume_name>` | The junction path to use when creating the volume.|

A convenient way to set all the required variable is to put them into a file named `varabless.yaml`.
All the playbooks will attempt to load this file and use any variables defined in it. Otherwise,
you can set them by using the `--extra-vars` flag when running the playbook.

So that you don't have to hardcode secrets into the playbook, or variable files, all the playbooks
will leverage an AWS Secrets Manager secret to retrieve the credentials for FSx for ONTAP file system.

Each secret should have two `keys`:
| Key | Value |
| --- |:--- |
| `username` | The username to use to authenticate with the FSx for ONTAP file system. |
| `password` | The password to use to authenticate with the FSx for ONTAP file system. |

Since this script leverages the AWS Ansible collection you will need to provide authentication credentials for it.
You can read more about how to do that [here](https://docs.ansible.com/ansible/latest/collections/amazon/aws/docsite/aws_ec2_guide.html#authentication).

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
