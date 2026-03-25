# EC2 User data scripts

## Introduction
These sample scripts provide a way to launch an AWS EC2 instance with `user data` that will create an FSxN
volume and LUN, mount it to the instance, while installing all the needed libraries and resources.

## Notes
- LUN size will be set to 90% of the volume size, the remaining space is needed for the LUN management operation.
  This means that usable volume size is 90% of the requested size.
- The process might take several minutes to be complete.

## Preperation

1. Create an AWS SecretsManager secret to hold the password of the account you plan to use to authenticate to the FSxN file system with.
The secret should be of type `other` with value set to `Plain Text` that holds just the password.
2. Create an AWS IAM role that has EC2 as the trusted entity and has permissions to read the secret value. Here is an example policy that will do that:
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "VisualEditor0",
          "Effect": "Allow",
          "Action": [
            "secretsmanager:GetSecretValue"
          ],
          "Resource": "arn:aws:secretsmanager:us-west-2:999999999:secret:fsxn-password-75WJ57"
        }
      ]
    }
    ```
    Replace the "Resource" ARN with the ARN of your secret.

## Deployment Options

There are two ways to deploy an EC2 instance with the needed user data script:
1. Copy the CloudFormation template found in the repo [EC2-cloud_formation.yaml](EC2-cloud_formation.yaml) to you local machine and deploy a CloudFormation stack using it. CloudFormation will prompt you for all the required parameters.
2. Follow the instruction below to deploy an EC2 instance from the AWS console.

## AWS console deployment

1. Download the needed script according to the instance type you want to run. Either [linux_userData.sh](linux_userData.sh)
for a Linux distribution or [windows_userData.ps1](windows_userData.ps1) for Windows. The Linux script has been tested
with `Amazon Linux 2023`, `Ubuntu 24.04`, `Red Hat Enterprise Linux 10` and `Debian 13` distributions,
while the Windows script is designed for `Windows Server 2025 Base`.

    Note that since AWS has a 16KB limit for the user data the linux_userData.sh script is made up of the variable
    assignment noted below, and a compressed, base64 encoded version of the `linux_userData_real.sh` script. When the
    `linux_userData.sh` script is run, it will decode and uncompress what was the `linux_userData_real.sh` script
    and run it.

    Once you have downloaded the script, open it in a text editor and set the required values as noted below.

    For the Linux version of the script, set the following values at the top of it:
    - SECRET_ARN - The ARN of the secret that has the password for the `ONTAP-USER`.
    - FSXN_ADMIN_IP - IP address, or hostname, of the FSxN management endpoint.
    - VOLUME_NAME - The name of the volume you want to create in your FSxN.
    - VOLUME_SIZE - The size of the volume you want to create in GB e.g [100]
    - SVM_NAME - The name of the SVM where the volume is to be created.
    - ONTAP_USER - The ONTAP user id you wish to authenticate with.
	
    For the Windows version of the script, set the following values at the top of it:
    - $secretId - secret ARN that holds the password for the `$user`.
    - $ip - IP address, or hostname, of the FSxN management endpoint.
    - $volName - The name of the volume you want to create in your FSxN. 
    - $volSize - The size of the volume you want to create in GB e.g [100]
    - $drive_letter - The drive letter to assign to the volume.
    - $user - The ONTAP user id you wish to authenticate with.
    - $svm_name - The name of the SVM where the volume is to be created.
	
2. Save the script file.

### For Linux installation:
<ol>
  <li>Launch new instance
    <ol>
      <li>Fill in the server name.</li>
      <li>Under the Quick Start tab select the Linux distribution of your choice. The supported distributions are: `Amazon Linux 2023`, `Ubuntu 24.04`, `Red Hat Enterprise Linux 10` and `Debian 13`</li>
      <li>Fill in the other settings based on your networking and business needs.</li>
      <li>Under 'Advanced details':
        <ol>
          <li>Set the 'IAM instance profile' to the policy you created in the preperation step above.</li>
          <li>At the bottom, under the 'User data' section, press 'choose file' and select the script saved above.</li>
        </ol>
      </li>
    </ol>
  </li>
  <li>Launch the instance.</li>
</ol>

The installation log file can be found at: `/var/log/iscsi-install.log`.
If an error occurs while the installation is running, the script will terminate and all installations and setup will roll back.
  
### For Windows installation:
<ol>
  <li>Launch new instance
    <ol>
      <li>Fill in the server name.</li>
      <li>Select 'Windows'.</li>
      <li>Under Amazon Machine Image select 'Windows Server 2025 Base'.</li>
      <li>Fill in any other setting based on your networking and business needs.</li>
      <li>Under the 'Advanced details':
        <ol>
          <li>Set the 'IAM instance profile' to the role you created in the steps above.</li>
          <li>At the bottom, under the 'User data' section, press 'choose file', and select the script saved above.</li>
        </ol>
      </li>
    </ol>
  </li>
  <li>Launch the instance.</li>
</ol>

The installation log file can be found at: `C:\Users\Administrator\install.log`.
If an error occurs while the installation is running, a message will be inserted into the
installation log file, it will attempt to roll back any work that it preformed, finally the script will terminate.

**Note:** It can take 10 to 15 minutes for the script to complete. Check the installation log file to confirm it is done.
The line `Uninstall script removed` should be at the bottom of the file when the script has finished.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2026 NetApp, Inc. All Rights Reserved.
