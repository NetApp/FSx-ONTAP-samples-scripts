# :warning: **NOTICE:**

This repository is no longer being maintain. However, all the code found here has been relocated to a new NetApp managed GitHub repository found here [https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Automation/Ansible/FSxN-Inventory-Report](https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Automation/Ansible/FSxN-Inventory-Report). Please refer to that repository for the latest updates. This repository is being left behind purely for historical purposes.

# Ansible Inventory Report
This Ansible playbook generates a report of all the FSx for ONTAP file systems within an AWS account.
In includes all the SVMs and Volumes. The format of the report is as follows:
```
Region: <region_name>
  File System ID: <file-system-id-1>
    SVM ID: <svm-id-1-1>
      Volumes:
        <volume-id-1-1-1> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
        <volume-id-1-1-2> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
    SVM ID: <svm-id-1-2>
      Volumes:
        <volume-id-1-2-2> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
        <volume-id-1-2-2> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
  File System ID: <file-system-id-2>
    SVM ID: <svm-id-2-1>
      Volumes:
        <volume-id-2-1-1> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
        <volume-id-2-1-2> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
    SVM ID: <svm-id-2-2>
      Volumes:
        <volume-id-2-2-1> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
        <volume-id-2-2-2> <volume-type> <security-style> <volume-size-in-megabytes> <volume-name>
```
Where:
  - \<volume-size-in-megabytes> is the provisioned size of the volume in megabytes.
  - \<security-style> is the security style of the volume (e.g. UNIX, NTFS).
  - \<volume-type> is the type of the volume (e.g. RW, DP).

## Requirements
- jq - A lightweight and flexible command-line JSON processor. Installation instructions can be found [here](https://jqlang.github.io/jq/download/)
- Ansible 2.9 or later. Installation instructions can be found [here](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- AWS Ansible collection. This should be included with the base installation of Ansible.

## Installation
There are three files used to create the report:
- `generate_report.yaml`: The Ansible playbook that generates the report.
- `processs_region.yaml`: A collection of tasks that will process all the FSxNs in a region.
- `get_all_fsxn_regions.yaml`: A collection of tasks that retrieves all the AWS regions, that are enabled for the account, where FSx for ONTAP is available.

## Configuration
There are a variable that can be changed at the top of the `generate_report.yaml` file:
- report\_name - Sets the file path of the report that will be generated. 

Since this script leverages the AWS Ansible collection as well as the `aws` cli, you will need to provide authentication credentials for them.
You can read more about how to do that [here](https://docs.ansible.com/ansible/latest/collections/amazon/aws/docsite/aws_ec2_guide.html#authentication).

## Usage
To generate the report copy the three files mentioned above and run the following command:
```bash
ansible-playbook generate_report.yaml
```

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
