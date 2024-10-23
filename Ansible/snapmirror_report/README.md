# Ansible SnapMirror Report
This Ansible playbook generates a report of all the FSx for ONTAP SnapMirror relationships within an AWS account.
The output of the report is a CSV file with the following columns:
- File System ID
- Source Path (svm:volume)
- Destination Path (svm:volume)
- State (e.g. snapmirrored, broken-off)
- Healthy (true or false)
- lag\_time (in "P#DT#H#M#S" format)

## Requirements
- Ansible 2.9 or later
- AWS collection

## Installation
There are three files used to create the report:
- `generate_report.yaml`: The Ansible playbook that generates the report.
- `processs_region.yaml`: A collection of tasks that will process all the FSxNs in a region.
- `get_all_fsxn_regions.yaml`: A collection of tasks that retrieves all the regions, that are enabled for the account, where FSx for ONTAP is available.

You will also need to create a file named (by default) `secrets_list.csv` that list the secret name for each FSx file system.
The format of the file should be:
```
file_system_id,secret_name
```
You should have all four of these files in a single directory.

## Configuration
There are a few variables that can be changed at the top of the `generate_report.yaml` file:
- report\_name - Sets the file path of the report that will be generated. 
- secrets\_list\_file - Sets the file path of the file that contains the list of FSx file systems and their secrets.
- secrets\_region - Set the region where the secrets are stored.

## Usage
To generate the report, run the following command:
```bash
ansible-playbook generate_report.yaml
```
After a successful run, the report will be saved to the file path specified in the `report_name` variable.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
