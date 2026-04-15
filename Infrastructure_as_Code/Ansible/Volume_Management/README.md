# Ansible Volume Management samples
This folder contains Ansible playbooks that can be used to manage volumes within a FSx for ONTAP file system.

They have been configured to use the new `use_lambda` feature that allows it to leverage an Workload Factory Link
to issue the API calls to the FSx for ONTAP file system which alleviates the requirement of the Ansible control
node to have network connectivity to the FSx for ONTAP file system. For more information on how to set up a
Workload Factory Link, please refer to the [NetApp Workload Factory documentation](https://docs.netapp.com/us-en/workload-fsx-ontap/links-overview.html).

The list of playbooks included in this folder is as follows:
- create\_snapshot.yaml
- delete\_snapshot.yaml
- create\_volume.yaml
- delete\_volume.yaml
- create\_volume\_and\_share.yaml
- delete\_volume\_and\_share.yaml

## Requirements
- Ansible 2.9 or later. Installation instructions can be found [here](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- NetApp ONTAP Ansible collection.
- AWS Ansible collection.
- An AWS secret with the credentials necessary to run the required volume APIs against the FSx for ONTAP file system. The required format of the secret is described below.

## Configuration
Each playbook requires various variables to be set in order to run.
| Variable | Used By Playbook | Required | Default | Description |
|:-------- |:----------------:|:--------:|:-------:|:-----------|
| fsxn\_hostname| All | Yes | None | The hostname, or IP address, of the FSxN where the volume resides.|
| vserver    | All | Yes | None | The name of the vserver where the volume resides.|
| secret\_name | All | Yes | None | The name of the AWS secret that contains the credentials to authenticate with the FSx for ONTAP file system.|
| volume\_name| All | Yes | None | The name of the volume you want to act on.|
| lambda\_function\_name| All | No | None | The name of the Workload Factory Link Lambda function to use when issuing API calls to the FSx for ONTAP file system.| 
| aws\_region | All | No | None | The AWS region where the Lambda function resides.|
| volume\_size| create\_volume\* | Yes | None | The size, in MiBs, of the volume to create.|
| security\_style | create\_volume\* | No | UNIX | The security style to use when creating the volume. Valid options are UNIX or NTFS.|
| aggr | create\_volume\* | No | aggr1 | The name of the aggregate to create the volume on.|
| volume\_type | create\_volume\* | No | RW | The type of volume to create. Valid options are RW and DP.|
| junction\_path | create\_volume\* | No | `/<volume_name>` | The junction path to use when creating the volume.|
| snapshot\_name | create\_snapshot | Yes | None | The name of the snapshot to create.|

A convenient way to set all the required variable is to put them into a file named `variables.yaml`.
All the playbooks will attempt to load this file and use any variables defined in it. Otherwise,
you can set them by using the `--extra-vars` flag when running the playbook. An example `variables.yaml`
file is included in this folder.

## Authentication
So that you don't have to hardcode secrets into the playbook, or variable files, all the playbooks
will leverage an AWS Secrets Manager secret to retrieve the credentials for FSx for ONTAP file system.

Each secret should have two `keys`:
| Key | Value |
| --- |:--- |
| `username` | The username to use to authenticate with the FSx for ONTAP file system. |
| `password` | The password to use to authenticate with the FSx for ONTAP file system. |

Since this script leverages the AWS Ansible collection you will need to provide authentication credentials for it.
You can read more about how to do that [here](https://docs.ansible.com/ansible/latest/collections/amazon/aws/docsite/aws_ec2_guide.html#authentication).

## Example Run:
Here is an example of running the `create_volume.yaml` playbook to create a new
volume named `vol1` with a size of 1024 MiBs on the `fsx` vserver:
```bash
$ ansible-playbook create_volume.yaml --extra-vars "volume_name=vol1 volume_size=1024 vserver=fsx"
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

PLAY [Playbook to create a volumes on an FSx for ONTAP file system.] *******************************************************

TASK [Ensure required variables are set.] **********************************************************************************
skipping: [localhost] => (item=volume_name)
skipping: [localhost] => (item=volume_size)
skipping: [localhost] => (item=vserver)
skipping: [localhost] => (item=secret_name)
skipping: [localhost]

TASK [Set security_style to unix if not provide.] **************************************************************************
ok: [localhost]

TASK [Set aggr to 'aggr1' if not provided.] ********************************************************************************
ok: [localhost]

TASK [Set volume_type to "rw" if not provided.] ****************************************************************************
ok: [localhost]

TASK [Set use_lambda to true if lambda_function_name is provided.] *********************************************************
ok: [localhost]

TASK [Set aws_provide to "default" if not provided.] ***********************************************************************
ok: [localhost]

TASK [Set junction path to "/<volume_name>" if not provided.] **************************************************************
ok: [localhost]

TASK [Ensure that aws_region has been provided if use_lambda is true.] *****************************************************
skipping: [localhost]

TASK [Set aws_region to "" if not set at this point.] **********************************************************************
skipping: [localhost]

TASK [Set lambda_function_name to "" if not set at this point.] ************************************************************
skipping: [localhost]

TASK [Get username and password from AWS secret.] **************************************************************************
ok: [localhost]

TASK [Create the volume] ***************************************************************************************************
changed: [localhost]

PLAY RECAP *****************************************************************************************************************
localhost                  : ok=8    changed=1    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0
```

The above example had a `variables.yaml` file with the following contents:
```yaml
fsxn_hostname: "10.0.0.13"
lambda_function_name: "lambda-8nlmlCR"
aws_region: "us-west-2"
secret_name: "fsxn/default"
```
## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
