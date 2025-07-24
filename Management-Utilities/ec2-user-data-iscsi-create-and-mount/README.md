# EC2 User data scripts

## Introduction
These sample scripts provide a way to launch an AWS EC2 instance with `user data` that will create an FSxN
volume and LUN, mount it to the instance, while installing all the needed libraries and resources.

## Notes
- LUN size will be set to 90% of the volume size, the remain space is needed for the the LUN managment operation.
  This means that usuable volume size is 90% of the requestd size.
- The process might take several minutes to be compleetd.

## Set Up
1. Create an AWS SecretsManager secret to hold the password of the account you plan to use to authenicate to the FSxN file system with.
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

3. Download the needed script according to the instance type you want to run (Linux or Windows).

    For the Linux version of the script, set the following values at the top of it:
    - SECRET_NAME - Secret name has has the password for the `ONTAP-USER`.
    - AWS_REGION - AWS secret manager region.
    - FSXN_ADMIN_IP - IP address, or hostname, of the FSxN management endpoint.
    - VOLUME_NAME - The name of the volume you want to create in your FSxN.
    - VOLUME_SIZE - The size of the volume you want to create in GB e.g [100g]
    - SVM_NAME - The name of the SVM where the volume is to be created.
    - ONTAP_USER - The ONTAP user id you wish to authenicate with.
	
    For the Windows version of the script, set the following values at the top of it:
    - $secretId - secret ARN that holds the password for the `$user`.
    - $ip - IP address, or hostname, of the FSxN management endpoint.
    - $volName - The name of the volume you want to create in your FSxN. 
    - $volSize - The size of the volume you want to create in GB e.g [100]
    - $drive_letter - The drive letter to assign to the volume.
    - $user - The ONTAP user id you wish to authenicate with.
    - $svm_name - The name of the SVM where the volume is to be created.
	
4. Save the script file.

## On AWS console EC2
  
### For Linux installation:
<ol>
  <li>Launch new instance
    <ol>
      <li>Fill in the server name.</li>
      <li>Select 'Amazon Linux'.</li>
      <li>Under Amazon Machine Image select 'Amazon Linux 2023 AMI'.</li>
      <li>Fill in the other settings based on your networking and business needs.</li>
      <li>Under 'Advanced details':
        <ol>
          <li>Set the 'IAM instance profile' to the policy you created in the steps above.</li>
          <li>At the bottom, under the 'User data' section, press 'choose file' and select the script saved above.</li>
        </ol>
      </li>
    </ol>
  </li>
  <li>Launch the instance.</li>
</ol>

The installation log file can be found at: `/home/ec2-user/install.log`.
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
If an error occurs while the installation is running, a message will be inserted into the installation log file, it will attempt to roll back any work that it preformed, finally the script will terminate.

**Note:** It can take 20 to 30 minutes for the script to compplete. Check the installation log file to confirm it is done. The line `Uninstall script removed` should be at the bottom of the file when the script has finished.
