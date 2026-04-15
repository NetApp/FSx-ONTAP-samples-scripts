################################################################################
# This Terraform configuration file creates an FSx for NetApp ONTAP volume
# using the AWS provider and then uses the NetApp ONTAP provider to create
# an CIFS share to the volume.
#
# The NetApp ONTAP provider can use either a Workload Factory link or a
# direct connection to the FSxN file system depending on which
# 'cx_provider_name' is used in the netapp-ontap_cifs_share resource.
#
# It is dependent on the variables defined below. The values can be set by
# adjusting the default value in the variable block or by providing
# the values in terraform.tfvars file.
#
################################################################################

variable "region" {
  description = "The AWS region where you want the resources deployed."
  type        = string
}

variable "volumeSize" {
  description = "The size of the volume in MiBs."
  type        = number
}

variable "volumeName" {
  description = "The name of the volume."
  type        = string
}

variable  "svmId" {
  description = "The SVM ID."
  type        = string
}

variable "secretId" {
  description = "The secret ID."
  type        = string
}

variable "fsEndpoint" {
  description = "The FSx management endpoint. Hostname or IP."
  type        = string
}

variable "linkLambdaName" {
  description = "The name of the Workload Factory Lambda function"
  type        = string
  default     = ""
}
#
# Define the required providers.
terraform {
  required_providers {
    netapp-ontap = {
      source = "NetApp/netapp-ontap"
      version = "~> 2.1"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
#
# Define the aws region to work in.
provider "aws" {
  region = var.region
}
#
# Define how to communicate with the FSxN file system.
provider "netapp-ontap" {
  connection_profiles = [
    {
      name = "direct"
      validate_certs = false
      hostname = var.fsEndpoint
      username = jsondecode(ephemeral.aws_secretsmanager_secret_version.fsxn_secret.secret_string)["username"]
      password = jsondecode(ephemeral.aws_secretsmanager_secret_version.fsxn_secret.secret_string)["password"]
    },
    {
      name = "aws"
      hostname = var.fsEndpoint
      username = jsondecode(ephemeral.aws_secretsmanager_secret_version.fsxn_secret.secret_string)["username"]
      password = jsondecode(ephemeral.aws_secretsmanager_secret_version.fsxn_secret.secret_string)["password"]
      aws_lambda = {
        function_name = var.linkLambdaName
        region = var.region
        shared_config_profile = "default"
      }
    }
  ]
}
#
# Define the aws volume.
resource "aws_fsx_ontap_volume" "aws_volume" {
  name                       = var.volumeName
  junction_path              = "/${var.volumeName}"
  size_in_megabytes          = var.volumeSize
  storage_efficiency_enabled = true
  storage_virtual_machine_id = var.svmId
  ontap_volume_type          = "RW"
}
#
# This data source is used to get the SVM name.
data "aws_fsx_ontap_storage_virtual_machine" "svm" {
  id = var.svmId
}
#
# This ephemeral resources is used to get the fsxn password.
ephemeral "aws_secretsmanager_secret_version" "fsxn_secret" {
  secret_id     = var.secretId
}
#
# Create the cifs share.
resource "netapp-ontap_cifs_share" "cifs_share" {
#   cx_profile_name = "direct"
   cx_profile_name = "aws"
   name            = var.volumeName
   path            = "/${var.volumeName}"
   svm_name        = data.aws_fsx_ontap_storage_virtual_machine.svm.name
   acls            = [
     {
       permission = "full_control"
       user_or_group = "Everyone"
       type = "windows"
     }
   ]
  depends_on = [
    aws_fsx_ontap_volume.aws_volume
  ]
}
