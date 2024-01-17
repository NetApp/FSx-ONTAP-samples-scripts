variable "fs_name" {
   description = "The deployed filesystem name"
   type = string
   default = "terraform-fsxn"
}

variable "vpc_id" {
   description = "The ID of the VPC in which the FSxN fikesystem should be deployed"
   type = string
}

variable "fsx_subnets" {
   description = "The IDs of the subnets fro which the FSxN filesystem will be assigned IP addresses"
   type = map
   default = {
      "primarysub" = ""
      "secondarysub" = ""
   }
}

variable "fs_capacity_size_gb" {
   description = "The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608"
   type = string
   default = "1024"
}

variable "deploy_type" {
   description = "The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1"
   type = string 
   default = "SINGLE_AZ_1"
}
       
variable "fs_tput_in_MBps" {
   description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
   type = string
   default = "256"
}

variable "svm_name" {
   description = "The name of the Storage Virtual Machine"
   type = string
   default = "first_svm"
}

variable "vol_info" {
   description = "Details for the volume creation"
   type = map
   default = {
     "vol_name" = "vol1"
     "junction_path" = "/vol1"
	  "size_mg" = 1024
	  "efficiency" = true
	  "tier_policy_name" = "AUTO"
	  "cooling_period" = 31
   }
}



