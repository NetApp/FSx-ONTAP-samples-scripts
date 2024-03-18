variable "fsx_name" {
   description = "The deployed filesystem name"
   type        = string
   default     = "terraform-fsxn"
}

variable "vpc_id" {
   description = "The ID of the VPC in which the FSxN fikesystem should be deployed"
   type        = string
   default     = "vpc-111111111"
}

variable "fsx_subnets" {
   description = "A list of IDs for the subnets that the file system will be accessible from. Up to 2 subnets can be provided."
   type        = map(any)
   default = {
      "primarysub"   = ""
      "secondarysub" = ""
   }
}

variable "fsx_capacity_size_gb" {
   description = "The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608"
   type        = number
   default     = 1024
}

variable "fsx_deploy_type" {
   description = "The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1"
   type        = string 
   default     = "MULTI_AZ_1"
}
       
variable "fsx_tput_in_MBps" {
   description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
   type        = number
   default     = 256
}

variable "fsx_admin_password" {
  description = "The ONTAP administrative password for the fsxadmin user that you can use to administer your file system using the ONTAP CLI and REST API"
  type        = string
  default     = "password"
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