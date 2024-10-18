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
   region = var.dr_aws_region
}

provider "aws" {
   alias = "prime-aws-region"
   region = var.prime_aws_region
}

data "aws_secretsmanager_secret_version" "ontap_prime_username_pass" {
  provider = aws.prime-aws-region
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
      hostname = join("", aws_fsx_ontap_file_system.terraform-fsxn.endpoints[0].management[0].ip_addresses)
      username = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["username"]
      password = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["password"]
      validate_certs = var.validate_certs
    }

  ]
}

resource "aws_fsx_ontap_file_system" "terraform-fsxn" {
  subnet_ids = var.dr_fsx_deploy_type == "MULTI_AZ_1" || var.dr_fsx_deploy_type == "MULTI_AZ_2" ? [var.dr_fsx_subnets["primarysub"], var.dr_fsx_subnets["secondarysub"]] : [var.dr_fsx_subnets["primarysub"]]
  preferred_subnet_id = var.dr_fsx_subnets["primarysub"]

  storage_capacity                = var.dr_fsx_capacity_size_gb
  security_group_ids              = var.dr_create_sg ? [element(aws_security_group.fsx_sg[*].id, 0)] : var.dr_security_group_ids
  deployment_type                 = var.dr_fsx_deploy_type
  throughput_capacity_per_ha_pair = var.dr_fsx_tput_in_MBps
  ha_pairs                        = var.dr_ha_pairs
  endpoint_ip_address_range       = var.dr_endpoint_ip_address_range
  route_table_ids                 = var.dr_route_table_ids
  dynamic "disk_iops_configuration" {
    for_each = length(var.dr_disk_iops_configuration) > 0 ? [var.dr_disk_iops_configuration] : []

    content {
      iops = try(disk_iops_configuration.value.iops, null)
      mode = try(disk_iops_configuration.value.mode, null)
    }
  }

  tags = merge(var.dr_tags, {Name = var.dr_fsx_name})
  weekly_maintenance_start_time =  var.dr_maintenance_start_time
  kms_key_id = var.dr_kms_key_id
  automatic_backup_retention_days = var.dr_backup_retention_days
  daily_automatic_backup_start_time = var.dr_backup_retention_days > 0 ? var.dr_daily_backup_start_time : null
  fsx_admin_password = jsondecode(data.aws_secretsmanager_secret_version.ontap_dr_username_pass.secret_string)["password"]
}

# Define a storage virtual machine.
resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
  file_system_id             = aws_fsx_ontap_file_system.terraform-fsxn.id
  name                       = var.dr_svm_name
  root_volume_security_style = var.dr_root_vol_sec_style
}

data "netapp-ontap_storage_volume_data_source" "my_vol" {
   for_each        = toset(var.list_of_volumes_to_replicate)
   cx_profile_name = "primary_clus"
   svm_name        = var.prime_svm
   name            = each.value
}

resource "netapp-ontap_storage_volume_resource" "volloop" {
   for_each = data.netapp-ontap_storage_volume_data_source.my_vol
   cx_profile_name = "dr_clus"
   name = "${each.value.name}_dp"
   type = "dp"
   svm_name = aws_fsx_ontap_storage_virtual_machine.mysvm.name
   aggregates = [
     {
       name = "aggr1"
     },
   ]
   space_guarantee = "none"
   space = {
       size = each.value.space.size
       size_unit =  each.value.space.size_unit
       logical_space = {
       enforcement = true
       reporting = true
     }
  }
  tiering = {
      policy_name = "all"
  }
  nas = {
    export_policy_name = "default"
    security_style = "unix"
    # junction_path = join("", ["/",each.value.name])
  }
}

# Now that we have the DP volumes created on the newly deployed destination cluster,
# let's get the intercluster LIFs so we can peer the clusters.

# For existing FSx ONTAP cluster
data "netapp-ontap_networking_ip_interfaces_data_source" "primary_intercluster_lifs" {
  cx_profile_name = "primary_clus"
  filter = {
     svm_name        = var.prime_svm
     name            = "inter*"  # Filter to only get intercluster LIFs
  }
}

# For newly created FSx ONTAP cluster
data "netapp-ontap_networking_ip_interfaces_data_source" "dr_intercluster_lifs" {
  cx_profile_name = "dr_clus"
  filter = {
     svm_name        = aws_fsx_ontap_storage_virtual_machine.mysvm.name
     name            = "inter*"  # Filter to only get intercluster LIFs
  }
}


# Now udse the LIF names and IP addresses to peer the clusters

resource "netapp-ontap_cluster_peers_resource" "cluster_peer" {
  cx_profile_name      = "primary_clus"  # Source cluster profile
  peer_cx_profile_name = "dr_clus"       # Destination (peer) cluster profile

  remote = {
    # Destination cluster (DR) intercluster LIF IPs
    ip_addresses = [for lif in data.netapp-ontap_networking_ip_interfaces_data_source.dr_intercluster_lifs.ip_interfaces : lif.ip_address]
  }

  source_details = {
    # Source cluster (primary) intercluster LIF IPs
    ip_addresses = [for lif in data.netapp-ontap_networking_ip_interfaces_data_source.primary_intercluster_lifs.ip_interfaces : lif.ip_address]
  }

  # Optional: Add authentication, passphrase or any other required settings
  # passphrase = var.cluster_peer_passphrase  # Optional, if you use passphrase for peering
  peer_applications = ["snapmirror"]
}
