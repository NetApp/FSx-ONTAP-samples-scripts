# Ansible Inventory Report
This Ansible playbook generates a report of all the FSx for ONTAP file systems within an AWS account.
In includes all the SVMs and Volumes.

## Requirements
- Ansible 2.9 or later
- AWS Ansible collection

## Installation
There are three files used to create the report:
- `generate_report.yaml`: The Ansible playbook that generates the report.
- `processs_region.yaml`: A collection of tasks that will process all the FSxNs in a region.
- `get_all_fsxn_regions.yaml`: A collection of tasks that retrieves all the AWS regions, that are enabled for the account, where FSx for ONTAP is available.

## Configuration
There are a variable that can be changed at the top of the `generate_report.yaml` file:
- report\_name - Sets the file path of the report that will be generated. 

## Usage
To generate the report, run the following command:
```bash
ansible-playbook generate_report.yaml
```

## Output
After a successful run, the report will be saved to the file path specified in the `report_name` variable.
The format of the report is as follows:
```
Region: <region_name>
  File System ID: <file-system-id-1>
    SVM ID: <svm-id-1-1>
      Volumes:
        <volume-id-1-1-1> <volume-size-in-megabytes> <security-style> <volume-type>
        <volume-id-1-1-2> <volume-size-in-megabytes> <security-style> <volume-type>
    SVM ID: <svm-id-1-2>
      Volumes:
        <volume-id-1-1-1> <volume-size-in-megabytes> <security-style> <volume-type>
        <volume-id-1-1-2> <volume-size-in-megabytes> <security-style> <volume-type>
  File System ID: <file-system-id-2>
    SVM ID: <svm-id-2-1>
      Volumes:
        <volume-id-2-1-1> <volume-size-in-megabytes> <security-style> <volume-type>
        <volume-id-2-1-2> <volume-size-in-megabytes> <security-style> <volume-type>
    SVM ID: <svm-id-2-2>
      Volumes:
        <volume-id-2-2-1> <volume-size-in-megabytes> <security-style> <volume-type>
        <volume-id-2-2-2> <volume-size-in-megabytes> <security-style> <volume-type>
```
Where:
  - \<volume-size-in-megabytes> is the provisioned size of the volume in megabytes.
  - \<security-style> is the security style of the volume (e.g. UNIX, NTFS).
  - \<volume-type> is the type of the volume (e.g. RW, DP).

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
