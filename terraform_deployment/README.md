# Deploy an ONTAP FSX file system using Terraform
This sample demonstrates how to deploy an FSX for Netapp ONTAP file system, including an SVM and a volume in that file system, using aws Terraform provider. 
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
* **main.tf** - the main set of configuration for this terraform sample

* **variables.tf** - Contains the variable definitions for this sample

* **terraform.tfvard** - Contains the variables assignments for this sample. Terraform will automatically use this file as it's main variables definition file as it uses the saved name. Note that if you change the file name you will need to specify that file on the command line with `-var-file`.
Exported values will override any of the variables in both the variables.tf file and the terraform.tfvars file

* **output.tf** - Contains output declarations of the resources created by this Terraform module. Terraform stores output values in the configuration's state file.

### What to expect

Running this terraform sample will result the following:
* Create a new FSX for Netapp ONTAP file system in your AWS account named "_terraform-fsxn_". The File System will be created with the following configuration parameters:
    * 1024Gb of storage capacity
    * Single AZ deployment type
    * 256Mbps of throughput capacity 

* Create a Storage Virtual Maching (svm) in this new File System named "_first_svm_"
* Create a new FlexVol volume in this svm named "_vol1_" with the following configuration parameters:
    * Size of 1024Mb
    * Storage efficiencies mechanism enabled
    * Auto tiering policy with 31 cooling days

> [!NOTE]
> All of the above configuration parameters can be modified for your preference by assigning your own values in the _terraform.tfvars_ file! 

## Prerequisites

### Terraform

Terraform should be installed in the server from which you are running this sample. Check out [this link](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for installation details. 

### AWS Account Setup

* An AWS Account with an administrative user in AWS IAM Identity Center



## Getting Started
--

## Usage Examples
--

## License