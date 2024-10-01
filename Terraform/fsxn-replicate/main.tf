terraform {
  required_providers {
    netapp-ontap = {
      source = "NetApp/netapp-ontap"
      version = "1.1.4"
    }

    aws = {
       source = "hashicorp/aws"
       version = ">= 5.68.0"
    }
  }
}

provider "aws" {
   region = var.secrets_aws_region
}

data "aws_secretsmanager_secret_version" "ontap_prime_username_pass" {
  secret_id = var.username_pass_secrets_id
}

data "aws_secretsmanager_secret_version" "ontap_dr_username_pass" {
  secret_id = var.dr_username_pass_secrets_id
}


provider "netapp-ontap" {
  # A connection profile defines how to interface with an ONTAP cluster or svm.
  # At least one is required.
  connection_profiles = [
    {
      name = "primary_clus"
      hostname = var.prime_hostname
      username = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["username"]
      password = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["password"]
      validate_certs = var.validate_certs
    },
    {
      name = "dr_clus"
      username = jsondecode(data.aws_secretsmanager_secret_version.ontap_dr_username_pass.secret_string)["username"]
      password = jsondecode(data.aws_secretsmanager_secret_version.ontap_dr_username_pass.secret_string)["password"]
      hostname = var.dr_hostname
      validate_certs = var.validate_certs
    },
  ]
}

data "netapp-ontap_storage_volume_data_source" "my_vol" {
   for_each        = toset(var.list_of_volumes_to_replicate)
   cx_profile_name = "primary_clus"
   svm_name        = var.prime_svm
   name            = each.value
}

resource "netapp-ontap_storage_volume_resource" "example" {
  cx_profile_name = "primary_clus"
  name = "rvwn_vol1_tf"
  svm_name = var.prime_svm
  aggregates = [
    {
      name = "aggr1"
    },
  ]
  space_guarantee = "none"
  snapshot_policy = "default"
  space = {
      size = 100
      size_unit = "gb"
    logical_space = {
      enforcement = true
      reporting = true
    }
  }
  tiering = {
      policy_name = "auto"
  }
  nas = {
    export_policy_name = "default"
    security_style = "unix"
      junction_path = "/rvwn_vol1_tf"
  }
}