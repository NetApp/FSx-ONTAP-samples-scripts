# :warning: **NOTICE:**

This repository is no longer being maintain. However, all the code found here has been relocated to a new NetApp managed GitHub repository found here [https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Management-Utilities/FSx-ONTAP-Rotate-Secret](https://github.com/NetApp/FSx-ONTAP-utils/tree/main/Samples/Management-Utilities/FSx-ONTAP-Rotate-Secret). Please refer to that repository for the latest updates. This repository is being left behind purely for historical purposes.

# Rotate FSxN File System Passwords

## Introduction
This sample provides a way to rotate a Secrets Manager secret that is used to hold the
password assigned to an FSxN file system or a FSxN Storage Virtual Machine.
It is a Lambda function that is expected to be invoked by the Secrets Manager rotation feature.
The Secrets Manager should invoke the function four times, each time with the `stage` field, in the `event` dictionary passed in, set to one of the following values:

| Stage      | Description |
|------------|-------------|
|createSecret|The function will create a new version of the secret with a "Version Staging ID" of "AWSPENDING". At this point the original secret is still be left as is and will be the default secret returned if no Version Staging ID is provided.|
|setSecret   |The function will update the password for the FSxN file system using the new version of the secret.|
|testSecret  |Currently no testing is performed. The Lambda function would have to be attached to the same VPC as the FSxN file system to test the password. Since that would potentially make it where you'd have to have a separate function for each FSxN deployment, and potentially have to setup AWS Endpoints for AWS services, a decision was made to not do that. If the Lambda function fails to set the password correctly, you can always use the AWS console, or API, to set it to whatever you need.|
|finishSecret|The function will promote the new password to the "AWSCURRENT" Version Staging ID. This will set the Version Staging ID of the old password to "AWSPREVIOUS".|

## Set Up
There are a couple way to you can leverage this sample. Either by manually creating a Lambda function with the appropriate permissions and setting up the Secrets Manager rotation service to use it, or by using the Terraform module provided in the `terraform` directory.
### Manual Method

#### Step 1 - Create a role for the Lambda function
The first step is to create a role for the Lambda function with the following permissions. It should have a trust
relationship with the AWS Lambda service.

| Permission              | Minimal Scope     |  Notes 
|:------------------------|:----------------|:----------------|
| secretsManager:GetSecretValue | \<secretARN> | \<secretARN> is the AWS ARN of the secret to rotate. |
| secretsManager:PutSecretValue | \<secretARN> | \<secretARN> is the AWS ARN of the secret to rotate. |
| secretsManager:UpdateSecretVersionStage | \<secretARN> | \<secretARN> is the AWS ARN of the secret to rotate. |
| secretsManager:DescribeSecret | \<secretARN> | \<secretARN> is the AWS ARN of the secret to rotate. |
| secretsmanager:GetRandomPassword | \* | The scope doesn't matter, since this function doesn't have anything to do with any AWS resources. |
| fsx:UpdateFileSystem | \<fileSystemARN> | \<fileSystemARN> is the AWS ARN of the FSxN file system to manage. |
| fsx:UpdateStorageVirtualMachine | \<svmARN> | \<svmARN> is the AWS ARN of the Storage Virtual Machine to manage. |
| logs:CreateLogGroup | arn:aws:logs:\<region>:\<accountID>:\* | This allows the Lambda function to create a log group in CloudWatch. This is optional but allows you to get diagnostic information from the Lambda function. |
| logs:CreateLogStream | arn:aws:logs:\<region>:\<accountID>:log-group:/aws/lambda/\<Lambda_function_name>:\* | This allows the Lambda function to create a log stream in CloudWatch. This is optional but allows you to get diagnostic information from the function.|
| logs:PutLogEvents | arn:aws:logs:\<region>:\<accountID>:log-group:/aws/lambda/\<Lambda_function_name>:\* | This allows the Lambda function to write log events to a log stream in CloudWatch. This is optional but allows you to get diagnostic information from the function.|

#### Step 2 - Create the Lambda Function
##### Step 2.1
Create a Lambda function with the following parameters:
- Authored from scratch.
- Uses the Python runtime.
- Set the permissions to the role created above.

##### Step 2.2 - Insert code
After you create the function, you will be able to insert the code included with this 
sample into the code box and click "Deploy" to save it.

##### Step 2.3 - Change permissisons
Change to the `Configuration` tab and select `Permissions` and add a `Resource-based policy` statement that will allow the
secretsmanager AWS service to invoke the Lambda function. Do that do the following:

- Click on Add Permission
- Then select "AWS Service"
- Put "Allow SecretsManager" in the StatementID (although, it doesn't really matter what you put there)
- The principal should already be set to `secretsmanager.amazonaws.com`
- Set action to `lambda:InvokeFunction`

#### Step 3 - Enable Secrets Manager Rotation
To enable the rotation of the secret, you will need go to the Secrets Manager page of the AWS console
and click on the secret you want to rotate, then:
##### Step 3.1 - Set the tags
The way Lambda function knows which FSxN file system, or which SVM, to update the password for is 
via the tags associated with the secret. The following are the tags that the program looks for:
|Tag Key|Tag Value|Description|
|:------|:--------|:----------|
|region|\<region\>|The region the FSxN file system resides in.|
|fsx_id|\<file-System-id\>|The FSxN file system id.|
|svm_id|\<svm-id\>|The Storage Virtual Machine id.|

Note that the Lambda function can only manage one password, so either set the value for the `fsx_id` or the `svm_id` tag, both not both.

:warning: **Warning:** If both the `fsx_id` and `svm_id` tags are set, the `svm_id` tag will be used and the fsx_id will be silently ignored.

Also note that the secret value will be a JSON object with the following fields:
- `username` - The username will either be set to 'fsxadmin' or 'vsadmin' depending on whether the `fsx_id` or `svm_id` tag is set.
- `password` - The password associated with the username.

##### Step 3.2 - Enable rotation feature
Click on the Rotation tab and then click on the "Edit rotation" button. That should bring up a 
pop-up window. Click on the "Automatic rotation" slider to enable the feature and then configure
the rotation schedule the way you want. The last step is to
select the rotation function that you created in the steps above and click on the "Save" button.

### Terraform Method
The Terraform module provided in the `terraform` directory can be used to create the Secrets Manager
secret setup to use a rotation policy that uses the Lambda function. It will create the following resources:
- A Lambda function used to rotate the secret.
- An IAM role that allows the Lambda function to rotate the secret.
- A Secrets Manager secret with a rotation enabled.

#### Prerequisites

1. [Terraform prerequisites](#terraform)
2. [AWS prerequisites](#aws-account-setup)

##### Terraform

| Name | Version |
|------|---------|
| terraform | >= 1.6.6 |
| aws provider | >= 5.25 |

##### AWS Account Setup

- You must have an AWS Account with necessary permissions to create and manage resources.
- Configure your AWS Credentials on the server running this Terraform module. This can be derived from
several sources, which are applied in the following order:
    1. Parameters in the provider configuration
    2. Environment variables
    3. Shared credentials files
    4. Shared configuration files
    5. Container credentials
    6. Instance profile credentials and Region

    This order matches the precedence used by the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-precedence) and the [AWS SDKs](https://aws.amazon.com/tools/).

> [!NOTE]
> In this sample, the AWS Credentials were configured through [AWS CLI](https://aws.amazon.com/cli/), which adds them to a shared configuration file (option 4 above). Therefore, this documentation only provides guidance on setting-up the AWS credentials with shared configuration file using AWS CLI.

#### Usage

This directory contains a shared Terraform module that can be referenced remotely. **No need to clone the repository in order to use it!**
To reference this module, create a new terraform folder in your local environment, add a main.tf file and modify it according to the instructions below.

##### AWS provider block

Add the AWS provider block to your local root `main.tf` file with the required configuration. For more information check [the docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Example:
```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">=5.25"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}
```
##### Reference this module

Add the following module block to your local `main.tf` file.
Make sure to replace all values within `< >` with your own variables.

```hcl
module "fsxn_rotate_secret" {
    source = "github.com/NetApp/FSx-ONTAP-samples-scripts/Management-Utilities/fsxn-rotate-secret/terraform"

    fsx_region = <region>              # The region the FSxN file system resides in.
    secret_region = <region>           # The region the secret resides in.
    aws_account_id = <aws_account_id>  # The AWS account id that the FSxN file system resides in.
    fsx_id = <fsx_id>
    svm_id = <svm_id>
    secretNamePrefix = "fsx_admin_secret"
    rotationFrequency = "rate(30 days)"
}
```
Note that the Lambda function can only manage one password, so either set the value for the `fsxId` or the `svmId` tag, but not both.

:warning: **Warning:** If both the `fsxId` and `svmId` tags are set, the `svmId` tag will be used and the fsxId will be silently ignored.

At this point, you can run `terraform init` and `terraform apply` to create the secret that will automatically rotate
the password for the FSxN file system or SVM.

#### Inputs
The following are the inputs for the module:
| Name | Description |  Type  |  Default  | Required |
|:-----|:------------|:------:|:---------:|:--------:|
| fsx_region | The region where the FSxN file system resides in. | string | | yes |
| secret_region | The region where the secret will resides in. | string | | yes |
| aws_account_id | The AWS account id that the FSxN file system resides in. Used to create roles with least privilege. | string |\*| no |
| fsx_id | The FSxN file system id. Note that either fsxId or svmId must be provided, but not both | string | | no |
| svm_id | The Storage Virtual Machine id. Note that either fsxId or svmId must be provided, but not both | string | | no |
| secret_name_prefix | The prefix to use for the secret name. | string | fsxn-secret | no |
| rotation_frequency | The frequency to rotate the password in AWS's "rate" or "cron" notation. | string | rate(30 days) | yes |

#### Outputs
The following are the outputs for the module:
| Name | Description |
|------|-------------|
| secret_arn | The ARN of the secret created. |
| secret_name | The name of the secret created. |
| lambda_arn | The ARN of the Lambda function created. |
| lambda_name | The name of the Lambda function created. |
| role_arn | The ARN of the IAM role created. |
| role_name | The name of the IAM role created. |

Note that the secret value will be a JSON object with the following fields:
- `username` - The username will either be set to 'fsxadmin' or 'vsadmin' depending on whether the `fsx_id` or `svm_id` tag is set.
- `password` - The password associated with the username.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
