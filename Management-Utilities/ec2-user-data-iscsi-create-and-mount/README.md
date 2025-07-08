# EC2 User data scripts

## Introduction
Those samples provides a way to launch AWS EC2 instances with user data scripts that will create FSxN volume and LUN, mount it to the instance,
while installing all the needed libraries and resources

## Set Up
Create secet in AWS secret manager, secret should be saved as text.
In IAM create policy that will allow to read the secret.
Set the following permissions:

Example AWS Policy  
{  
&nbsp;&nbsp;&nbsp;"Version": "2012-10-17",  
&nbsp;&nbsp;&nbsp;"Statement": [  
&nbsp;&nbsp;&nbsp;{  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Sid": "VisualEditor0",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Effect": "Allow",  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Action": [  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"secretsmanager:GetSecretValue"  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;],  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Resource": "arn:aws:secretsmanager:us-west-2:847548833:secret:test/posh-75WJ57"  
&nbsp;&nbsp;&nbsp;}  
&nbsp;&nbsp;&nbsp;]    
}

1. AWS Amazon Linux
  First, get the needed script according to the instance type you want to run.
  Set the following values in the script:
   - SECRET_NAME - Secret name has it been saved in AWS secret manager
   - AWS_REGION - AWS secret manager region
   - FSXN_ADMIN_IP - FSxN administrator IP
   - VOLUME_NAME - The name of the volume you want to create in your FSxN. 
   - VOLUME_SIZE - The size of the volume you want to create in GB e.g [100g]
   - SVM_NAME - The SVM name, if you have another SVM which is not the default 'fsx'.

Save the script file.
In AWS console EC2 - Launch new instance fill server name and select 'Windows' select 'Microsoft Windows Server 2025 Base' fill any other needed data,
Go to 'IAM instance profile' and create or use instance profile with the policy you have just created.
Go to Advanced details and scroll down to User data, press 'choose file' select the script file you have saved.
Launch the instance.
The installation log file can be found at: /home/ec2-user/output.txt 
If an error occurs while the installation is running, the process will be terminated and all installations and setup will roll back.

2. AWS Microsoft Windows Server 2025 
  Set the following values in the script:
   - $secretId - secret ARN from yours AWS secret manager
   - $ip - FSxN administrator IP
   - $password - FSxN administrator password
   - $volName - The name of the volume you want to create in your FSxN. 
   - $volSize - The size of the volume you want to create in GB e.g [100]
   - $drive_letter - The drive letter to assign to the volume.

  Save the script file.

## In AWS console EC2 - 
  
For Linux installation:
  - Launch new instance fill in the server name and select 'Amazon Linux' then select under Amazon Machine Image select 'Amazon Linux 2023 AMI' fill in any other required data, 
    Go to 'IAM instance profile' and create or use instance profile with the policy you have just created.
    Go to Advanced details and scroll down to User data, press 'choose file', and select the script file you have saved.
    Launch the instance.
    The installation log file can be found at: /home/ec2-user/install.log
  
For Windows installation:
  - Launch new instance fill in the server name and select 'Windows', then select under Amazon Machine Image select 'Windows Server 2025 Base', fill in any other required data, 
    go to Advanced details and scroll down to User data, press 'choose file', and select the script file you have saved.
    Launch the instance.
    The installation log file can be found at: C:\Users\Administrator\install.log
