# Export NetApp FSxN to a CloudFormation Template

## Overview
This folder provides a script that will create an CloudFormation template based on the current configuration of an existing FSx for ONTAP file system.

## Prerequisites
- An FSxN file system you want to create an CloudFormation template for.
- An AWS account with permissions to "describe" the FSxN file system and its virtual storage machines, and volumes.
- The AWS CLI installed and configured on your local machine. You can find instructions on how to do that [here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).

## Running the script

The script takes the following parameters:
- `-f fs-id`: The ID of the FSxN file system you want to create the CloudFormation template for. This is a required parameter.
- `-n name`: Is an optional name to be appended to all the volumes, svms and NetBIOS names. This is so you could test the CloudFormation template while the original machine is still running.

The script will output the CloudFormation template in JSON format. You can redirect this output to a file if you want to save it.

Note that since you can't retrieve credentials from the FSxN configuration the script will create
parameters that will allow you to provide an AWS Secrets Manager secret that should contain the credentials.
There will be one parameter for the password of the 'fsxadmin' account. That secret will just need one 'key'
named "password" with the desired fsxadmin password. There will also be a parameter for each SVMs that has an
Active Directory configured for it so you can provide a secret that should have a 'username' and 'password' key
that will be used to join the SVM to the domain.

An example run:
```
$ python export_fsxn_cf.py -f fs-0123456789abcdef0 -n test > fsxn_template.json
Warning: Volume rvnw_vol_autogrow does not have a junction path yet it is required for a Cloudformation template so setting it to /rvnw_vol_autogrow
Warning: Volume unixdata does not have a junction path yet it is required for a Cloudformation template so setting it to /unixdata
Warning: Volume effictest2 is a DP volume and cannot have the StorageEfficiencyEnabled property, removing it from the CloudFormation template.
Warning: Volume effictest2 is a DP volume and cannot have the SnapshotPolicy property, removing it from the CloudFormation template.
Warning: Volume effictest2 is a DP volume and cannot have the SecurityStyle property, removing it from the CloudFormation template.
Warning: Could not find root volume for SVM fsa. Setting the security style to UNIX
```

## Notes
- For multi availability zone deployments, the script will do the following in regards to the Endpoint IP Address Range:
    - If the file system is in the 198.19.0.0/16 address range (the AWS default), the script will not provide an address range forcing AWS to just allocate a new address range from the 198.19.0.0/16 CIDR block.
    - If it isn't in the 198.19.0.0/16 address range then it will create a parameter so you can specify a new address range for testing purposes, with a default set to the current address range.
- Since AWS requires you to provide a junction path when creating a volume, if the script finds a volume without a junction path it will set it to `/volume_name`. A warning message will be outputed if this happens you alert you.
- Since AWS doesn't allow you to specify these parameters when creating a DP type volume, their current settings will be removed from the CloudFormation template:
    - SecurityStyle
    - SnapshotPolicy
    - StorageEfficiencyEnabled
- If, for some reason, the script can't find the attributes of the root volume of a SVM (unlikely but there are reasons how this can happen), it will set the security style to 'NTFS' if the SVM has a Active Directory configuration, otherwise it will assume an 'UNIX' security style. A warning message will be printed if this happens to alert you.
- While some testing was performed, hence the `-n` option, not for all possible FSxN configurations were tested. If you run into any issues with the script, or have suggestions for improvements, please open an [issue](https://github.com/NetApp/FSx-ONTAP-samples-scripts/issues) on GitHub.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2025 NetApp, Inc. All Rights Reserved.
