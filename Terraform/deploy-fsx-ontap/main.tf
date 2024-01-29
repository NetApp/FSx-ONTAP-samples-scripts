// TODO add SG rule for SnapMirror

# Copyright (c) NetApp, Inc.
# SPDX-License-Identifier: Apache-2.0

/* 
  The following resources are a Security Group followed by ingress and egress rules for FSx ONTAP. 
  The Security Group is not required for deploying FSx ONTAP, but is included here for completeness.

  - If you wish to skip this resource, pass the variable "create_sg" as false to the module block. Otherwise, pass true.

  - If you wish to use the Security Group, choose the relevant source for the ingress rules as cidr block and pass the variable "cidr_for_sg" to the module block.

  Note that a source reference for a Security Group is optional, but is considered to be a best practice.
  The rules below are just a suggestion for basic functionality.
*/

resource "aws_security_group" "fsx_sg" {
  count       = var.create_sg ? 1 : 0
  name        = "fsx_sg"
  description = "Allow FSx ONTAP required ports"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "all_icmp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Allow all ICMP traffic"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_tcp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Remote procedure call for NFS"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 111
  to_port           = 111
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_udp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Remote procedure call for NFS"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 111
  to_port           = 111
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "cifs" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "NetBIOS service session for CIFS"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 139
  to_port           = 139
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_tcp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Simple network management protocol for log collection"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 161
  to_port           = 162
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_udp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Simple network management protocol for log collection"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 161
  to_port           = 162
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "smb_cifs" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Microsoft SMB/CIFS over TCP with NetBIOS framing"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_tcp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "NFS mount"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 635
  to_port           = 635
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_udp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "NFS mount"
  cidr_ipv4         = var.cidr_for_sg
  from_port         = 635
  to_port           = 635
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

/*
  The following resources are for deploying a complete FSx ONTAP file system. 
  The code below deploys the following resources in this order:
  1. A file system 
  2. A storage virtual machine
  3. A volume within the storage virtual machine

  Every resource include both optional and required parameters, separated by a comment line.
  Feel free to add or remove optional parameters as needed.
  The current settings are just a suggestion for basic functionality.
*/

resource "aws_fsx_ontap_file_system" "terraform-fsxn" {
  // REQUIRED PARAMETERS 
  subnet_ids          = [var.fsx_subnets["primarysub"], var.fsx_subnets["secondarysub"]]
  preferred_subnet_id = var.fsx_subnets["primarysub"]

  // OPTIONAL PARAMETERS
  storage_capacity                  = var.fsx_capacity_size_gb
  security_group_ids                = var.create_sg ? [element(aws_security_group.fsx_sg.*.id, 0)] : []
  deployment_type                   = var.fsx_deploy_type
  throughput_capacity               = var.fsx_tput_in_MBps
  weekly_maintenance_start_time     = var.fsx_maintenance_start_time
  kms_key_id                        = var.kms_key_id
  automatic_backup_retention_days   = var.backup_retention_days
  daily_automatic_backup_start_time = var.daily_backup_start_time
  storage_type                      = var.storage_type
  disk_iops_configuration           = var.disk_iops_configuration
  fsx_admin_password = var.fsx_admin_password
  route_table_ids    = var.route_table_ids
  tags               = var.tags
  # endpoint_ip_address_range = ""
}

resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
  // REQUIRED PARAMETERS
  file_system_id = aws_fsx_ontap_file_system.terraform-fsxn.id
  name           = var.svm_name

  // OPTIONAL PARAMETERS
  root_volume_security_style = var.root_vol_sec_style
  tags                       = var.tags
  # active_directory_configuration {}
}

resource "aws_fsx_ontap_volume" "myvol" {
  // REQUIRED PARAMETERS
  name                       = var.vol_info["vol_name"]
  size_in_megabytes          = var.vol_info["size_mg"]
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.mysvm.id

  // OPTIONAL PARAMETERS
  junction_path              = var.vol_info["junction_path"]
  ontap_volume_type          = var.vol_info["vol_type"]
  storage_efficiency_enabled = var.vol_info["efficiency"]
  tiering_policy {
    name           = var.vol_info["tier_policy_name"]
    cooling_period = var.vol_info["cooling_period"]
  }
  bypass_snaplock_enterprise_retention = var.vol_info["bypass_sl_retention"]
  copy_tags_to_backups                 = var.vol_info["copy_tags_to_backups"]
  security_style                       = var.vol_info["sec_style"]
  skip_final_backup                    = var.vol_info["skip_final_backup"]
  # snaplock_configuration {}
  snapshot_policy = "NONE"
  tags            = var.tags
}
