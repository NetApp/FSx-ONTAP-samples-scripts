# Ansible SnapMirror Report
This Ansible playbook generates a report of all the FSx for ONTAP SnapMirror relationships within an AWS account.
The output of the report is a CSV file with the following columns:
- File System ID
- Source Path (svm:volume)
- Destination Path (svm:volume)
- State (e.g. snapmirrored, broken-off)
- Healthy (true or false)
- lag\_time (in "P#DT#H#M#S" format. See below for an explanation)

The lag\_time format always starts with the letter 'P' and if the lag time is more than 24 hours it is followed by
a number and the letter 'D'. The number is the number of days. The next character is always a 'T' and is followed by
a number, letter pairs, where the letter is either an 'H', 'M', or 'S'. If the letter is 'H' then number before it is
the number of hours. If the letter is 'M' then number before it is the number of minutes. If the letter is 'S' then
number before it is the number of seconds. For example, 'P1DT2H3M4S' represents 1 day, 2 hours, 3 minutes, and 4 seconds.

## Requirements
- jq - A lightweight and flexible command-line JSON processor. Installation instructions can be found [here](https://jqlang.github.io/jq/download/)
- Ansible 2.9 or later. Installation instructions can be found [here](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- AWS Ansible collection. This should be included with the base installation of Ansible.
- AWS secret(s) with the credentials necessary to run SnapMirror ONTAP APIs against the FSx for ONTAP file systems. The required format of the secret is described below.

## Installation
There are three files used to create the report:
- `generate_report.yaml`: The Ansible playbook that generates the report.
- `processs_region.yaml`: A collection of tasks that will process all the FSxNs in a region.
- `get_all_fsxn_regions.yaml`: A collection of tasks that retrieves all the regions, that are enabled for the account, where FSx for ONTAP is available.

You will also need to create a file named (by default) `secrets_list.csv` that list the secret name for each FSx file systems.
The format of the file should be:
```
file_system_id,secret_name
```
NOTE: Do not add any spaces before or after the file\_system\_id or secret\_name.

Each secret should have two `keys`:
| Key | Value |
| --- | --- |
| `username` | The username to use to authenticate with the FSx for ONTAP file system. |
| `password` | The password to use to authenticate with the FSx for ONTAP file system. |

## Configuration
There are a few variables that can be changed at the top of the `generate_report.yaml` file:
- report\_name - Sets the file path of the report that will be generated. 
- secrets\_list\_file - Sets the file path of the file that contains the list of FSx file systems and their secrets. See above for more information.
- secrets\_region - Set the region where the secrets are stored.

Since this script leverages the AWS Ansible collection as well as the `aws` cli, you will need to provide authentication credentials for them.
You can read more about how to do that [here](https://docs.ansible.com/ansible/latest/collections/amazon/aws/docsite/aws_ec2_guide.html#authentication).

## Usage
To generate the report, run the following command:
```bash
ansible-playbook generate_report.yaml
```
After a successful run, the report will be stored in the file specified by the `report_name` variable.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
