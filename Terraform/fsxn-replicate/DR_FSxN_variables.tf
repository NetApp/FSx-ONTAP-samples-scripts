# Variables for the Disaster Recovery FSx for ONTAP file system to be created.

variable "dr_aws_region" {
   description = "AWS region where you want the Secondary(DR) FSx for ONTAP file system."
   type        = string
   default     = ""
}

variable "dr_fsx_name" {
   description = "The name to assign to the destination FSx for ONTAP file system."
   type        = string
   default     = ""
}

variable "dr_clus_name" {
   description = "This is the name of the cluster given for ONTAP TF connection profile. This is a user creatred value, that can be any string. It is referenced in many ONTAP TF resources."
   type        = string
   default     = "dr_clus"
}

variable "dr_fsx_deploy_type" {
   description = "The file system deployment type. Supported values are 'MULTI_AZ_1', 'SINGLE_AZ_1', 'MULTI_AZ_2', and 'SINGLE_AZ_2'. MULTI_AZ_1 and SINGLE_AZ_1 are Gen 1. MULTI_AZ_2 and SINGLE_AZ_2 are Gen 2."
   type        = string
   default     = "SINGLE_AZ_1"
   validation {
      condition = contains(["MULTI_AZ_1", "SINGLE_AZ_1", "MULTI_AZ_2", "SINGLE_AZ_2"], var.dr_fsx_deploy_type)
      error_message = "Invalid deployment type. Valid values are MULTI_AZ_1, SINGLE_AZ_1, MULTI_AZ_2 or SINGLE_AZ_2."
   }
}

variable "dr_fsx_subnets" {
   description = "The primary subnet ID, and secondary subnet ID if you are deploying in a Multi AZ environment, file system will be accessible from. For MULTI_AZ deployment types both subnets are required. For SINGLE_AZ deployment type, only the primary subnet is used."
   type        = map(any)
   default = {
      "primarysub"   = "subnet-11111111"
      "secondarysub" = "subnet-33333333"
   }
}

variable "dr_fsx_capacity_size_gb" {
   description = "The storage capacity in GiBs of the FSx for ONTAP file system. Valid values between 1024 (1 TiB) and 1048576 (1 PiB). Gen 1 deployment types are limited to 192 TiB. Gen 2 Multi AZ is limited to 512 TiB. Gen 2 Single AZ is limited to 1 PiB."
   type        = number
   default     = 1024
   validation {
      condition = var.dr_fsx_capacity_size_gb >= 1024 && var.dr_fsx_capacity_size_gb <= 1048576
      error_message = "Invalid capacity size. Valid values are between 1024 (1TiB) and 1045876 (1 PiB)."
   }
}

variable "dr_fsx_tput_in_MBps" {
   description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096 for Gen 1, and 384, 768, 1536, 3072 and 6144 for Gen 2."
   type        = string
   default     = "128"
   validation {
      condition = contains(["128", "256", "384", "512", "768", "1024", "1536", "2048", "3072", "4086", "6144"], var.dr_fsx_tput_in_MBps)
      error_message = "Invalid throughput value. Valid values are 128, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4086, 6144."
   }
}

variable "dr_ha_pairs" {
   description = "The number of HA pairs in the file system. Valid values are from 1 through 12. Only single AZ Gen 2 deployment type supports more than 1 HA pair."
   type        = number
   default     = 1
   validation {
      condition = var.dr_ha_pairs >= 1 && var.dr_ha_pairs <= 12
      error_message = "Invalid number of HA pairs. Valid values are from 1 through 12."
   }
}

variable "dr_endpoint_ip_address_range" {
   description = "The IP address range that the FSx for ONTAP file system will be accessible from. This is only used for Multi AZ deployment types and must be left a null for Single AZ deployment types."
   type        = string
   default     = null
}

variable "dr_route_table_ids" {
   description = "An array of routing table IDs that will be modified to allow access to the FSx for ONTAP file system. This is only used for Multi AZ deployment types and must be left as null for Single AZ deployment types."
   type        = list(string)
   default     = []
}

variable "dr_disk_iops_configuration" {
  description = "The SSD IOPS configuration for the file system. Valid modes are 'AUTOMATIC' (3 iops per GB provisioned) or 'USER_PROVISIONED'. NOTE: Due to a bug in the AWS FSx provider, if you want AUTOMATIC, then leave this variable empty. If you want USER_PROVISIONED, then add a 'mode=USER_PROVISIONED' (with USER_PROVISIONED enclosed in double quotes) and 'iops=number' where number is between 1 and 160000."
  type        = map(any)
  default     = {}
}

variable "dr_tags" {
  description = "Tags to be applied to the FSx for ONTAP file system. The format is '{Name1 = value, Name2 = value}' where value should be enclosed in double quotes."
  type        = map(any)
  default = {}
}

variable "dr_maintenance_start_time" {
  description = "The preferred start time to perform weekly maintenance, in UTC time zone. The format is 'D:HH:MM' format. D is the day of the week, where 1=Monday and 7=Sunday."
  type        = string
  default     = "7:00:00"
}

variable "dr_kms_key_id" {
  description = "ARN for the KMS Key to encrypt the file system at rest. Defaults to an AWS managed KMS Key."
  type        = string
  default     = null
}

variable "dr_backup_retention_days" {
  description = "The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days."
  type        = number
  default     = 0
  validation {
    condition = var.dr_backup_retention_days >= 0 && var.dr_backup_retention_days <= 90
    error_message = "Invalid backup retention days. Valid values are between 0 and 90."
  }
}

variable "dr_daily_backup_start_time" {
  description = "A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set."
  type        = string
  default     = "00:00"
}

variable "dr_svm_name" {
   description = "The name of the Storage Virtual Machine"
   type        = string
   default     = "fsx_dr"
}

variable "dr_root_vol_sec_style" {
  description = "Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED (although MIXED is not recommended). All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume."
  type        = string
  default     = "UNIX"
}

/*
 * These last set of variables have to do with a security group that can be optionally
 * created. The security group will have all the ingress rules that will allow access
 * to all the protocols that an FSx for ONTAP file system supports (e.g. SMB, NFS, etc). See the security_groups.tf
 * for more information.
 *
 * If you decide to create the security group, you can specify either the CIDR block to
 * be used as the source to the ingress rules OR the ID of a security group to be used as
 * the source to the ingress rules. You can't specify both.
 *
 * If you decide not to create the security group, you must set the security_group_id to
 * the ID of the security group that you want to use.
 *
 */
variable "dr_create_sg" {
  description = "Determines whether the Security Group should be created as part of this deployment or not."
  type        = bool
  default     = true
}

variable "dr_security_group_ids" {
  description = "If you are not creating the security group, provide a list of IDs of security groups to be used."
  type        = list(string)
  default     = []
}

variable "dr_security_group_name_prefix" {
  description = "The prefix to the security group name that will be created."
  type        = string
  default     = "fsxn-sg"
}

variable "dr_cidr_for_sg" {
  description = "The cidr block to be used for the created security ingress rules. Set to an empty string if you want to use the source_sg_id as the source."
  type        = string
  default     = "10.0.0.0/8"
}

variable "dr_source_sg_id" {
  description = "The ID of the security group to allow access to the FSx for ONTAP file system. Set to an empty string if you want to use the cidr_for_sg as the source."
  type        = string
  default     = ""
}

variable "dr_vpc_id" {
  description = "The VPC ID where the DR FSx for ONTAP file system and security group will be created."
  type        = string
  default     = ""
}

variable "dr_username_pass_secrets_id" {
   description = "Name of secret ID in AWS secrets. This secret needs to be in the same region as the DR FSx for ONTAP file system."
   type        = string
   default     = ""
}

variable "dr_snapmirror_policy_name" {
   description = "Name of snamirror policy to create"
   type        = string
   default     = ""
}

variable "dr_transfer_schedule" {
   description = "The schedule used to update asynchronous relationships."
   type        = string
   default     = "hourly"
}

variable "dr_retention" {
  description = "Rules for Snapshot copy retention."
  type        = string
  default     = <<-EOF
[{
  "label": "weekly",
  "count": 4
},
{
  "label": "daily",
  "count": 7
}]
EOF
}

