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
      name = var.prime_clus_name
      hostname = join("", data.aws_fsx_ontap_file_system.source_fsxn.endpoints[0].management[0].ip_addresses)
      username = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["username"]
      password = jsondecode(data.aws_secretsmanager_secret_version.ontap_prime_username_pass.secret_string)["password"]
      validate_certs = var.validate_certs
    },
    {
      name = var.dr_clus_name
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

data "netapp-ontap_storage_volume_data_source" "src_vols" {
   for_each        = toset(var.list_of_volumes_to_replicate)
   cx_profile_name = var.prime_clus_name
   svm_name        = var.prime_svm
   name            = each.value
}

variable "size_in_mb" {
  type = map(string)

  # Conversion to MBs
  default = {
    "mb" = 1
    "MB" = 1
    "gb" = 1024
    "GB" = 1024
    "tb" = 1024*1024
    "TB" = 1024*1024
  }
}


resource "aws_fsx_ontap_volume" "dp_volumes" {
  for_each = data.netapp-ontap_storage_volume_data_source.src_vols
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.mysvm.id
  name     = "${each.value.name}_dp"
  ontap_volume_type = "DP"
  size_in_megabytes = each.value.space.size * lookup(var.size_in_mb, each.value.space.size_unit, 0)
  tiering_policy {
    name = "ALL"
  }
  skip_final_backup = true
}

# Now that we have the DP volumes created on the newly deployed destination cluster,
# let's get the intercluster LIFs so we can peer the clusters.


# For now let's try to get the source and destination IC LIFs via AWS TF provider.
data "aws_fsx_ontap_file_system" "source_fsxn" {
  provider = aws.prime-aws-region
  id = var.prime_fsxid
}

# Now udse the LIF names and IP addresses to peer the clusters

resource "netapp-ontap_cluster_peers_resource" "cluster_peer" {
  cx_profile_name      = var.prime_clus_name  # Source cluster profile
  peer_cx_profile_name = var.dr_clus_name       # Destination (peer) cluster profile

  remote = {
    # Destination cluster (DR) intercluster LIF IPs
    ip_addresses = aws_fsx_ontap_file_system.terraform-fsxn.endpoints[0].intercluster[0].ip_addresses
  }

  source_details = {
    # Source cluster (primary) intercluster LIF IPs
    ip_addresses = data.aws_fsx_ontap_file_system.source_fsxn.endpoints[0].intercluster[0].ip_addresses
  }

  # Optional: Add authentication, passphrase or any other required settings
  # passphrase = var.cluster_peer_passphrase  # Optional, if you use passphrase for peering
  peer_applications = ["snapmirror"]
}

resource "netapp-ontap_svm_peers_resource" "peer_svms" {
  cx_profile_name = var.dr_clus_name
  svm = {
    name = aws_fsx_ontap_storage_virtual_machine.mysvm.name
  }
  peer = {
    svm = {
      name = var.prime_svm
    }
    cluster = {
      name = var.prime_cluster_vserver
    }
    peer_cx_profile_name = var.prime_clus_name
  }
  applications = ["snapmirror", "flexcache"]
  depends_on = [
    netapp-ontap_cluster_peers_resource.cluster_peer
  ]
}

locals {
  dr_retention_parsed = jsondecode(var.dr_retention)
}

resource "netapp-ontap_snapmirror_policy_resource" "snapmirror_policy_async" {
  # required to know which system to interface with
  cx_profile_name = var.dr_clus_name
  name = var.dr_snapmirror_policy_name
  svm_name = aws_fsx_ontap_storage_virtual_machine.mysvm.name
  type = "async"
  transfer_schedule_name = var.dr_transfer_schedule
  retention = local.dr_retention_parsed
}


resource "netapp-ontap_snapmirror_resource" "snapmirror" {
  for_each = data.netapp-ontap_storage_volume_data_source.src_vols
  cx_profile_name = var.dr_clus_name
  source_endpoint = {
     path = join(":",[var.prime_svm,each.value.name])
  }
  destination_endpoint = {
     path = join(":",[aws_fsx_ontap_storage_virtual_machine.mysvm.name, "${each.value.name}_dp"])
  }
  policy = {
     name = netapp-ontap_snapmirror_policy_resource.snapmirror_policy_async.name
  }
  depends_on = [
    netapp-ontap_svm_peers_resource.peer_svms,
    aws_fsx_ontap_volume.dp_volumes
  ]
}
