variable "aws_secretsmanager_region" {
   description = "The AWS region where the secret is stored. Can be different from the region where the FSxN file system is deployed."
   type        = string
   default     = "us-east-2"
}

variable "fsx_secret_name" {
   description = "The name of the AWS SecretManager secret that holds the ONTAP administrative password for the fsxadmin user that you can use to administer your file system using the ONTAP CLI and REST API."
   type        = string
   default     = "fsx_secret"
}

variable "fsx_capacity_size_gb" {
   description = "The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608."
   type        = number
   default     = 1024
   validation {
      condition = var.fsx_capacity_size_gb >= 1024 && var.fsx_capacity_size_gb <= 196608
      error_message = "Invalid capacity size. Valid values are between 1024 and 196608."
   }
}

variable "fsx_deploy_type" {
   description = "The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1"
   type        = string 
   default     = "MULTI_AZ_1"
   validation {
      condition = contains(["MULTI_AZ_1", "SINGLE_AZ_1"], var.fsx_deploy_type)
      error_message = "Invalid deployment type. Valid values are MULTI_AZ_1 and SINGLE_AZ_1."
   }
}
       
variable "fsx_name" {
   description = "The deployed filesystem name"
   type        = string
   default     = "terraform-fsxn"
}

variable "fsx_region" {
   description = "The AWS region where the FSxN file system to be deployed."
   type        = string
   default     = "us-west-2"
}

variable "fsx_subnets" {
   description = "A list of subnets IDs that the file system will be accessible from. For MULTI_AZ_1 deployment type, provide both subnets. For SINGLE_AZ_1 deployment type, only the primary subnet is used."
   type        = map(any)
   default = {
      "primarysub"   = "subnet-22222222"
      "secondarysub" = "subnet-33333333"
   }
}

variable "fsx_tput_in_MBps" {
   description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
   type        = number
   default     = 128
   validation {
      condition = contains([128, 256, 512, 1024, 2048, 4096], var.fsx_tput_in_MBps)
      error_message = "Invalid throughput value. Valid values are 128, 256, 512, 1024, 2048, and 4096."
   }
}

variable "svm_name" {
   description = "The name of the Storage Virtual Machine"
   type        = string
   default     = "first_svm"
}

variable "vol_info" {
   description = "Details for the volume creation"
   type = map(any)
   default = {
      "vol_name"         = "vol1"
      "junction_path"    = "/vol1"
	    "size_mg"          = 1024
	    "efficiency"       = true
	    "tier_policy_name" = "AUTO"
	    "cooling_period"   = 31
   }
}

variable "vpc_id" {
   description = "The ID of the VPC in which the FSxN fikesystem should be deployed"
   type        = string
   default     = "vpc-11111111"
}
