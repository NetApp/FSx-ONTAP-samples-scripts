variable "name" {
  description = "The name to assign to the FSx for ONTAP file system."
  type        = string
  default     = "fsxn"
}

variable "deployment_type" {
  description = "The file system deployment type. Supported values are 'MULTI_AZ_1', 'SINGLE_AZ_1', 'MULTI_AZ_2', and 'SINGLE_AZ_2'. MULTI_AZ_1 and SINGLE_AZ_1 are Gen 1. MULTI_AZ_2 and SINGLE_AZ_2 are Gen 2."
  type        = string
  default     = "MULTI_AZ_1"
  validation {
      condition = contains(["MULTI_AZ_1", "SINGLE_AZ_1", "MULTI_AZ_2", "SINGLE_AZ_2"], var.deployment_type)
      error_message = "Invalid deployment type. Valid values are MULTI_AZ_1, SINGLE_AZ_1, MULTI_AZ_2 or SINGLE_AZ_2."
  }
}

variable "capacity_size_gb" {
  description = "The storage capacity in GiBs of the FSxN file system. Valid values between 1024 (1 TiB) and 1048576 (1 PiB). Gen 1 deployment types are limited to 192 TiB. Gen 2 Multi AZ is limited to 512 TiB. Gen 2 Single AZ is limited to 1 PiB."
  type        = number
  default     = 1024
  validation {
      condition = var.capacity_size_gb >= 1024 && var.capacity_size_gb <= 1048576
      error_message = "Invalid capacity size. Valid values are between 1024 (1TiB) and 1045876 (1 PiB)."
  }
}

variable "throughput_in_MBps" {
  description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096 for Gen 1, and 384, 768, 1536, 3072 and 6144 for Gen 2."
  type        = string
  default     = "128"
  validation {
      condition = contains(["128", "256", "384", "512", "768", "1024", "1536", "2048", "3072", "4086", "6144"], var.throughput_in_MBps)
      error_message = "Invalid throughput value. Valid values are 128, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4086, 6144."
  }
}

variable "disk_iops_configuration" {
  description = "The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provisioned) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx Terraform provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVISIONED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in double quotes) and 'iops=number' where number is between 1 and 160000."
  type        = map(any)
  default     = {}
}

variable "ha_pairs" {
   description = "The number of HA pairs in the file system. Valid values are from 1 through 12. Only the Single AZ Gen 2 deployment type supports more than 1 HA pair."
   type        = number
   default     = 1
   validation {
      condition = var.ha_pairs >= 1 && var.ha_pairs <= 12
      error_message = "Invalid number of HA pairs. Valid values are from 1 through 12."
   }
}

variable "subnets" {
  description = "A map specifying the subnets where the management and data endpoints will be deployed. There are two suppoted keys: 'primarysub' which specfies where the 'active' node's endpoint will be located. 'secondarysub' where the standby node's endpoint will be located. Both must be specified if you are deploying a MULTI_AZ file system. Only the primary subnet is used for a SINGLE_AZ file system."
  type        = map(string)
}

variable "endpoint_ip_address_range" {
   description = "The IP address range that the FSxN file system will be accessible from. This is only used for Mutli AZ deployment types and must be left a null for Single AZ deployment types."
   type        = string
   default     = null
}

variable "route_table_ids" {
  description = "An array of routing table IDs that will be modified to allow access to the FSxN file system. This is only used for Multi AZ deployment types and must be left as null for Single AZ deployment types."
  type        = list(string)
  default     = null
}

variable "maintenance_start_time" {
  description = "The preferred start time to perform weekly maintenance, in UTC time zone. The format is 'D:HH:MM' format. D is the day of the week, where 1=Monday and 7=Sunday."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "ARN for the KMS Key to encrypt the file system at rest. Defaults to an AWS managed KMS Key."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days."
  type        = number
  default     = 0
  validation {
    condition = var.backup_retention_days >= 0 && var.backup_retention_days <= 90
    error_message = "Invalid backup retention days. Valid values are between 0 and 90."
  }
}

variable "daily_backup_start_time" {
  description = "A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set."
  type        = string
  default     = null
}

variable "tags" {
  description = "A map defining tags to be applied to the FSxN file system. The format is '{Name1 = value, Name2 = value}'."
  type        = map(any)
  default = null
}

/*
 * The next three variables have to do with the creation of the secrets that will contain the FSxN and SVM passwords.
 */
variable "aws_account_id" {
  description = "The AWS account ID. Used to create account specific permissions on the secrets that are created. Use the default for less specific permissions."
  type        = string
  default     = "*"
}

variable "secrets_region" {
  description = "The AWS region where the secrets for the FSxN file system and SVM will be deployed."
  type        = string
  default     = ""
}

variable "secret_name_prefix" {
  description = "The prefix to the secret name that will be created that will contain the FSxN passwords (system, and SVM)."
  type        = string
  default     = "fsxn-secret"
}

/*
 * The next three variables have to do with the initial SVM and volume creation.
 */
variable "svm_name" {
  description = "name of the Storage Virtual Machine, (a.k.a. vserver)."
  type        = string
  default     = "fsx"
}

variable "root_vol_sec_style" {
  description = "Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume."
  type        = string
  default     = "UNIX"
}

variable "vol_info" {
  description = "Details for the initial volume creation."
  type = object({
    vol_name              = optional(string, "vol1")
    junction_path         = optional(string, "/vol1")
    size_mg               = optional(number,  2048000)
    efficiency            = optional(bool,    true)
    tier_policy_name      = optional(string, "AUTO")
    cooling_period        = optional(string,  31)
    vol_type              = optional(string, "RW")
    copy_tags_to_backups  = optional(bool,    false)
    sec_style             = optional(string, "UNIX")
    skip_final_backup     = optional(bool,    false)
    snapshot_policy       = optional(string, "default")
  })
  default = {}
}

/*
 * These last set of variables have to do with a security group that can be optionally
 * created. The security group will have all the ingress rules that will allow access
 * to all the protocols that an FSxN supports (e.g. SMB, NFS, etc).
 *
 * If you decide to create the security group, you can specify either the CIDR block to
 * be used as the source to the ingress rules OR the ID of a security group to be used as
 * the source to the ingress rules. You can't specify both.
 *
 * If you decide you don't want a security group created, you need to set
 * "create_sg" to false and set security_group_id to the ID of the security group you
 * want to use.
 */
variable "create_sg" {
  description = "Determines whether the Security Group should be created as part of this deployment or not."
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "If you are not creating the security group, provide a list of IDs of the security groups to be used."
  type        = list(string)
  default     = []
}

variable "security_group_name_prefix" {
  description = "The prefix to the security group name that will be created."
  type        = string
  default     = "fsxn-sg"
}

variable "cidr_for_sg" {
  description = "The cidr block to be used for the created security ingress rules. Set to an empty string if you want to use the source_sg_id as the source."
  type        = string
  default     = ""
}

variable "source_sg_id" {
  description = "The ID of the security group to allow access to the FSxN file system. Set to an empty string if you want to use the cidr_for_sg as the source."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created."
  type        = string
  default     = ""
}
