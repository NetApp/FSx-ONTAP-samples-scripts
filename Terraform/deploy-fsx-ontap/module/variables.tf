/*
 * If you want to set the nam eof your FSxN file system, you must set a "Name"
 * tag equal to the desired name. Feel free to add additional tags as needed.
 */
variable "tags" {
  description = "Tags to be applied to the resources"
  type        = map(any)
  default = {
     "Name" = "terraform-fsxn"
  }
}

variable "create_sg" {
  description = "Determines whether the SG should be deployed as part of this execution or not"
  type        = bool
  default     = true
}

variable "security_group_id" {
  description = "If you are not creating the SG, provide the ID of the SG to be used"
  type        = string
  default     = ""
}

/*
 * If you decide to allow this module to create a security group, you can specify
 * either a CIDR block to be used for the security group ingress rules OR the ID of
 * an security group to be used as the source to the ingress rules.
 * You can't specify both.
 */
variable "cidr_for_sg" {
  description = "cidr block to be used for the created security ingress rules."
  type        = string
  default     = "10.0.0.0/8"
}

variable "source_security_group_id" {
  description = "The ID of the security group to allow access to the FSxN file system."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "The ID of the VPC in which the FSxN fikesystem should be deployed"
  type        = string
  default     = ""
  validation  {
    condition = var.vpc_id != ""
    error_message = "You must provide the ID of the VPC in which the FSxN file system should be deployed."
  }
}

variable "fsx_subnets" {
  description = "The subnets from where the file system will be accessible from. For MULTI_AZ_1 deployment type, provide both primvary and secondary subnets. For SINGLE_AZ_1 deployment type, only the primary subnet is used."
  type        = map(string)
  default = {
       "primarysub" = "subnet-111111111"
       "secondarysub" = "subnet-222222222"
  }
}

variable "fsx_capacity_size_gb" {
  description = "The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608"
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
       
variable "fsx_tput_in_MBps" {
  description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
  type        = number
  default     = 128
  validation {
    condition = contains([128, 256, 512, 1024, 2048, 4096], var.fsx_tput_in_MBps)
    error_message = "Invalid throughput value. Valid values are 128, 256, 512, 1024, 2048, and 4096."
 }
}

variable "fsx_maintenance_start_time" {
  description = "The preferred start time (in d:HH:MM format) to perform weekly maintenance, in the UTC time zone."
  type        = string
  default     = "1:00:00"
}

variable "kms_key_id" {
  description = "ARN for the KMS Key to encrypt the file system at rest, Defaults to an AWS managed KMS Key."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days."
  type        = number
  default     = 0
}

variable "daily_backup_start_time" {
  description = "A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set."
  type        = string
  default     = "00:00"
}

variable "disk_iops_configuration" {
  description = "The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provided) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVIDEDED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in doube quotes) and 'iops=number' where number is between 1 and 160000."
  type        = map(any)
  default     = {}
}

variable "fsx_secret_name" {
  description = "The name of the secure where the FSxN passwood is stored"
  type        = string
  default     = ""
  validation {
    condition = var.fsx_secret_name != ""
    error_message = "You must provide the name of the secret where the FSxN password is stored."
  }
}

variable "route_table_ids" {
  description = "Specifies the VPC route tables in which your file system's endpoints will be created. You should specify all VPC route tables associated with the subnets in which your clients are located. By default, Amazon FSx selects your VPC's default route table. Note, this variable is only used for MULTI_AZ_1 type deployments."
  type        = list(any)
  default     = null
}

variable "svm_name" {
  description = "The name of the Storage Virtual Machine"
  type        = string
  default     = "first_svm"
}

variable "root_vol_sec_style" {
  description = "Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume."
  type        = string
  default     = "UNIX"
}

variable "vol_info" {
  description = "Details for the volume creation"
  type = map(any)
  default = {
   "vol_name"              = "vol1"
   "junction_path"         = "/vol1"
	 "size_mg"               = 1024
	 "efficiency"            = true
	 "tier_policy_name"      = "AUTO"
	 "cooling_period"        = 31
    "vol_type"             = "RW"
    "bypass_sl_retention"  = false
    "copy_tags_to_backups" = false
    "sec_style"            = "UNIX"
    "skip_final_backup"    = false
  }
}

variable "vol_snapshot_policy" {
  description = "Specifies the snapshot policy for the volume"
  type        = map(any)
  default     = null
}
