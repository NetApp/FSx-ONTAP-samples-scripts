variable "create_sg" {
   description = "Determines whether the SG should be deployed as part of this execution or not"
   type = bool
   default = false
}

variable "cidr_for_sg" {
   description = "cide block to be used for the ingress rules"
   type = string
   default = "0.0.0.0/0"
}

variable "fsx_name" {
   description = "The deployed filesystem name"
   type = string
   default = "terraform-fsxn"
}

variable "vpc_id" {
   description = "The ID of the VPC in which the FSxN fikesystem should be deployed"
   type = string
   default = "vpc-111111111"
}

variable "fsx_subnets" {
   description = "The IDs of the subnets fro which the FSxN filesystem will be assigned IP addresses"
   type = map
   default = {
      "primarysub" = ""
      "secondarysub" = ""
   }
}

variable "fsx_capacity_size_gb" {
   description = "The storage capacity (GiB) of the FSxN file system. Valid values between 1024 and 196608"
   type = number
   default = 1024
}

variable "fsx_deploy_type" {
   description = "The filesystem deployment type. Supports MULTI_AZ_1 and SINGLE_AZ_1"
   type = string 
   default = "SINGLE_AZ_1"
}
       
variable "fsx_tput_in_MBps" {
   description = "The throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
   type = number
   default = 256
}

variable "fsx_maintenance_start_time" {
   description = "The preferred start time (in d:HH:MM format) to perform weekly maintenance, in the UTC time zone."
   type = string
   default = "00:00:00"
}

variable "kms_key_id" {
   description = "ARN for the KMS Key to encrypt the file system at rest, Defaults to an AWS managed KMS Key."
   type = string
   default = ""
}

variable "backup_retention_days" {
   description = "The number of days to retain automatic backups. Setting this to 0 disables automatic backups. You can retain automatic backups for a maximum of 90 days."
   type = number
   default = 0
}

variable "daily_backup_start_time" {
   description = "A recurring daily time, in the format HH:MM. HH is the zero-padded hour of the day (0-23), and MM is the zero-padded minute of the hour. Requires automatic_backup_retention_days to be set."
   type = string
   default = "00:00"
}

variable "disk_iops_configuration" {
   description = "The SSD IOPS configuration for the Amazon FSx for NetApp ONTAP file system"
   type = map
   default = {
      "iops" = 3000
      "mode" = "AUTOMATIC"
   }
}

variable "ha_pairs" {
   description = "The number of ha_pairs to deploy for the file system. Valid values are 1 through 6. Recommend only using this parameter for 2 or more ha pairs."
   type = number
   default = 1
}

variable "fsx_admin_password" {
   description = "The ONTAP administrative password for the fsxadmin user that you can use to administer your file system using the ONTAP CLI and REST API"
   type = string
}

variable "storage_type" {
   description = "The filesystem storage type"
   type = string
   default = "SSD"
}

variable "tput_capacity_in_MBps" {
   description = "Sets the throughput capacity (in MBps) for the file system that you're creating. Valid values are 128, 256, 512, 1024, 2048, and 4096. This parameter should only be used when specifying not using the ha_pairs parameter."
   type = number
   default = 256
}

variable "tput_capacity_per_pair_in_MBps" {
   description = "Sets the throughput capacity (in MBps) for the file system that you're creating. Valid values are 3072,6144. This parameter should only be used when specifying the ha_pairs parameter."
   type = number
   default = 3072
}

variable "svm_name" {
   description = "The name of the Storage Virtual Machine"
   type = string
   default = "first_svm"
}

variable "root_vol_sec_style" {
   description = "Specifies the root volume security style, Valid values are UNIX, NTFS, and MIXED. All volumes created under this SVM will inherit the root security style unless the security style is specified on the volume."
   type = string
   default = "UNIX"
}

variable "ad_configuration" {
   description = "Configuration block that Amazon FSx uses to join the FSx ONTAP Storage Virtual Machine(SVM) to your Microsoft Active Directory (AD) directory."
   type = map
   default = {
      "netbios_name" = "first_svm"
      "self_managed_active_directory_configuration" = {
         "dns_ips" = []
         "domain_name" = "corp.example.com"
         "password" = ""
         "username" = ""
         "file_system_administrators_group" = "Domain Admins"
         "organizational_unit_distinguished_name" = "NONE"
      }
   }   
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
     "vol_type" = "RW"
     "bypass_sl_retention" = false
     "copy_tags_to_backups" = false
     "sec_style" = "UNIX"
     "skip_final_backup" = false
   }
}

variable "vol_snaplock_configuration" {
   description = "The SnapLock configuration for an FSx for ONTAP volume"
   type = map
   default = {
      "audit_log_volume" = false
      "snaplock_type" = "COMPLIANCE"
      "privileged_delete" = "DISABLED"
      "volume_append_mode_enabled" = false
      "retention_period" = {
         "default_retention" = {
            "type" = "UNSPECIFIED"
            "value" = 0
         }
         "maximum_retention" = {
            "type" = "UNSPECIFIED"
            "value" = 0
         }
         "minimum_retention" = {
            "type" = "UNSPECIFIED"
            "value" = 0
         }
      }
      "autocommit_period" = {
         "type" = "NONE"
         "value" = 0
      }
   }
}

variable "vol_snapshot_policy" {
   description = "Specifies the snapshot policy for the volume"
   type = map
   default = {
      "Name" = "terraform-fsxn"
   }
}

variable "tags" {
   description = "Tags to be applied to the resources"
   type = map
   default = {
      "Name" = "terraform-fsxn"
   }
}