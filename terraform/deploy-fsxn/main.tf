terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.25.0"
    }
  }

}

provider "aws" {
  region = "us-west-2"
}

resource "aws_fsx_ontap_file_system" "rvwn-terra-fsxn" {
   storage_capacity = var.fs_capacity_size_gb
   subnet_ids = [var.fsx_subnets["primarysub"]]
   deployment_type = var.deploy_type
   throughput_capacity = var.fs_tput_in_MBps
   preferred_subnet_id = var.fsx_subnets["primarysub"]
   tags = {
	Name = "rvwn-fsx1"
   }
}

resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
  file_system_id = output.my_filesystem_id
  name           = var.svm_name
}

resource "aws_fsx_ontap_volume" "myvol" {
  name                       = var.vol_info["vol_name"]
  junction_path              = var.vol_info["junction_path"]
  size_in_megabytes          = var.vol_info["size_mg"]
  storage_efficiency_enabled = var.vol_info["efficiency"]
  storage_virtual_machine_id = output.my_svm_id

  tiering_policy {
    name           = var.vol_info["tier_policy_name"]
    cooling_period = var.vol_info["cooling_period"]
  }
}


