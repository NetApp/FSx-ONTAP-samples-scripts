# Deploy an ONTAP FSx file-system using Terraform
This sample demonstrates how to deploy an FSx for NetApp ONTAP file system, including an SVM and a FlexVolume in that file system, using AWS Terraform provider. 
Follow the instructions below to use this sample in your own environment.

## Table of Contents
* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Getting Started](#getting-started)
* [Usage Examples](#usage-examples)
* [License](#license)

## Introduction
### Repository Overview
This is a standalone Terraform configutation repository that contains the following files:
* **main.tf** - The main set of configuration for this terraform sample

* **variables.tf** - Contains the variable definitions for this sample

* **terraform.tfvard** - Contains the variables assignments for this sample. Terraform will automatically use this file as it's main variables definition file as it uses the saved name. Note that if you change the file name you will need to specify that file on the command line with `-var-file`.
Exported values will override any of the variables in both the variables.tf file and the terraform.tfvars file

* **output.tf** - Contains output declarations of the resources created by this Terraform module. Terraform stores output values in the configuration's state file

### What to expect

Running this terraform sample will result the following:
* Create a new FSx for Netapp ONTAP file-system in your AWS account named "_terraform-fsxn_". The file-system will be created with the following configuration parameters:
    * 1024Gb of storage capacity
    * Single AZ deployment type
    * 256Mbps of throughput capacity 

* Create a Storage Virtual Maching (SVM) in this new file-system named "_first_svm_"
* Create a new FlexVol volume in this SVM named "_vol1_" with the following configuration parameters:
    * Size of 1024Mb
    * Storage efficiencies mechanism enabled
    * Auto tiering policy with 31 cooling days

> [!NOTE]
> All of the above configuration parameters can be modified for your preference by assigning your own values in the _terraform.tfvars_ file! 

## Prerequisites

1. [Terraform prerequisits](#terraform)
2. [AWS prerequisits](#aws-account-setup)

### Terraform

Terraform should be installed in the server from which you are running this sample. Check out [this link](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for installation details. 

### AWS Account Setup

* You must have an AWS Account with necessary permissions to create and manage resources
* Configure your AWS Credentials on the server running this Terraform module. This can be derived from several sources, which are applied in the following order:
    1. Parameters in the provider configuration
    2. Environment variables
    3. Shared credentials files
    4. Shared configuration files
    5. Container credentials
    6. Instance profile credentials and Region

    This order matches the precedence used by the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-precedence) and the [AWS SDKs](https://aws.amazon.com/tools/).

    > [NOTE!]
    > In this sample, the AWS Credentials were configured through [AWS CLI](https://aws.amazon.com/cli/), which adds them to a shared configuration file (option 4 above). Therefore, this documentation only provides guidance on setting-up the AWS credentials with shared configuration file using AWS CLI.

    #### Configure AWS Credentials using AWS CLI

    The AWS Provider can source credentials and other settings from the shared configuration and credentials files. By default, these files are located at `$HOME/.aws/config` and `$HOME/.aws/credentials` on Linux and macOS, and `"%USERPROFILE%\.aws\credentials"` on Windows.

    If no named profile is specified, the `default` profile is used. Use the `profile` parameter or `AWS_PROFILE` environment variable to specify a named profile.

    The locations of the shared configuration and credentials files can be configured using either the parameters `shared_config_files` and `shared_credentials_files` or the environment variables `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE`.

    For example:
    ```ruby
    provider "aws" {
        shared_config_files      = ["/Users/tf_user/.aws/conf"]
        shared_credentials_files = ["/Users/tf_user/.aws/creds"]
        profile                  = "customprofile"
    }
    ```

    There are several ways to set your credentials and configuration setting using AWS CLI. We will use [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure/index.html) command:

    Run the following command to quickly set and view your credentails, region, and output format. The following example shows sample values:

    ```shell
    $ aws configure
    AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
    AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
    Default region name [None]: us-west-2
    Default output format [None]: json
    ```

    To list configuration data, use the [`aws configire list`](https://docs.aws.amazon.com/cli/latest/reference/configure/list.html) command. This command lists the profile, access key, secret key, and region configuration information used for the specified profile. For each configuration item, it shows the value, where the configuration value was retrieved, and the configuration variable name.



## Usage

#### 1. Clone the repository
In your server's terminal, navigate to the location where you wish to store this Terraform repository, and clone the repository using your preferred authentication type. In this example we are using HTTPS clone:

```shell
$ git clone https://github.com/NetApp/FSxN-Samples.git
```

#### 2. Navigate to the directory
```shell
$ cd terraform_deployment
```

#### 3. Initialize Terraform
This directory represents a standalone Terraform module. Run the following command to initialize the module and install all dependencies:
```shell
$ terraform init
```

A succesfull initialization should display the following output:
```shell

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.25.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
You can see that Terraform recognizes the modules required by our configuration: `hashicorp/aws`.

#### 4. Update Variables

Open the **`terraform.tfvars`** file in your preferred text editor. Update the values of the variables to match your preferences and save the file. This will ensure that the Terraform code deploys resources according to your specifications.

**Make sure to replace the values with ones that match your AWS environment and needs.**

#### 5. Create a Terraform plan
Run the following command to create an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:
```shell
$ terraform plan
```
Ensure that the proposed changes match what you expected before you apply the changes!

#### 6. Apply the Terraform plan
Run the following command to execute the Terrafom code and apply the changes proposed in the `plan` step:
```shell
$ terraform apply
```

## License