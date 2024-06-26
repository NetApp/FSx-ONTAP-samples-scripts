terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.25.0"
    }
  }
}
#
# Define a default provider.
provider "aws" {
  region = var.fsx_region
}
#
# Since the Secrets Manager might be in a different region, create a separate provider for it.
provider "aws" {
  alias  = "secrets"
  region = var.aws_secretsmanager_region
}

/*
 * The following resources are for deploying a complete FSx ONTAP file system. 
 * The code below deploys the following resources in this order:
 * 1. A file system 
 * 2. A storage virtual machine
 * 3. A volume within the storage virtual machine
 *
 * Every resource include both optional and required parameters, separated by a comment line.
 * Feel free to add or remove optional parameters as needed.
 * The current settings are just a suggestion for basic functionality.
 */
resource "aws_fsx_ontap_file_system" "terraform-fsxn" {
// REQUIRED PARAMETERS 
  // For SINGLE_AZ deployment, only the primary subnet can be specified.
  subnet_ids = var.fsx_deploy_type == "MULTI_AZ_1" ? [var.fsx_subnets["primarysub"], var.fsx_subnets["secondarysub"]] : [var.fsx_subnets["primarysub"]]
  preferred_subnet_id = var.fsx_subnets["primarysub"]

// OPTIONAL PARAMETERS
  storage_capacity    = var.fsx_capacity_size_gb
  security_group_ids  = [aws_security_group.fsx_sg.id]
  deployment_type     = var.fsx_deploy_type
  throughput_capacity = var.fsx_tput_in_MBps
  fsx_admin_password  = data.aws_secretsmanager_secret_version.fsx_password.secret_string
  tags = {
	  Name = var.fsx_name
  }

// Additional optional parameters that you may want to specify:
  # weekly_maintenance_start_time = "00:00:00"
  # kms_key_id = ""
  # automatic_backup_retention_days = 0
  # daily_automatic_backup_start_time = "00:00"
  # disk_iops_configuration = ""
  # endpoint_ip_address_range = ""
  # ha_pairs = 1
  # route_table_ids = []
  # throughput_capacity_per_ha_pair = 0
}
#
# Define a storage virtual machine.
resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
// REQUIRED PARAMETERS
  file_system_id      = aws_fsx_ontap_file_system.terraform-fsxn.id
  name                = var.svm_name

// OPTIONAL PARAMETERS
  # root_volume_security_style = ""
  # tags                       = {}
  # active_directory_configuration {}
}
#
# Define a volume within the storage virtual machine.
resource "aws_fsx_ontap_volume" "myvol" {
// REQUIRED PARAMETERS
  name                       = var.vol_info["vol_name"]
  size_in_megabytes          = var.vol_info["size_mg"]
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.mysvm.id

// OPTIONAL PARAMETERS
  junction_path              = var.vol_info["junction_path"]
  ontap_volume_type          = "RW"
  storage_efficiency_enabled = var.vol_info["efficiency"]
  tiering_policy {
    name           = var.vol_info["tier_policy_name"]
    cooling_period = var.vol_info["cooling_period"]
  }
  // The following argument disables the creation of a post-deletion backup. Comment out to allow the creation of a post-deletion backup.
  skip_final_backup = true
  # bypass_snaplock_enterprise_retention = true
  # copy_tags_to_backups = false
  # security_style = "UNIX"
  # snaplock_configuration {}
  # snapshot_policy {}
  # tags = {}  
}
#
# The next two data blocks retrieve the secret from Secrets Manager.
data "aws_secretsmanager_secret" "fsx_secret" {
  provider = aws.secrets
  name = var.fsx_secret_name
}
data "aws_secretsmanager_secret_version" "fsx_password" {
  provider = aws.secrets
  secret_id = data.aws_secretsmanager_secret.fsx_secret.id
}
