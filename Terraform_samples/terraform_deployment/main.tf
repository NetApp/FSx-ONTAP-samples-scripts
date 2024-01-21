// TODO: Consider using aws secret manager resource to keep the created password string
// TODO: Consider making this a module


/* 
  The following resources are a Security Group followed by ingress and egress rules for FSx ONTAP. 
  The Security Group is not required for deploying FSx ONTAP, but is included here for completeness.

  - If you wish to skip this resource, comment out the resource blocks of the Security Group and the rules.

  - If you wish to use the Security Group, choose the relevant source for the ingress rules (can be either cidr block or security group id)
    and uncomment the relevant line in the resource block. Make sure you add your specific value as well. 

  Note that a source reference for a Security Group is optional, but is considered to be a best practice.
  Feel free to add, remove, or change the rules as needed. The rules below are just a suggestion for basic functionality.
*/

resource "aws_security_group" "fsx_sg" {
  name        = "fsx_sg"
  description = "Allow FSx ONTAP required ports"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "all_icmp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Allow all ICMP traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Remote procedure call for NFS"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 111
  to_port           = 111
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Remote procedure call for NFS"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 111
  to_port           = 111
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "cifs" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NetBIOS service session for CIFS"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 139
  to_port           = 139
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Simple network management protocol for log collection"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 161
  to_port           = 162
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Simple network management protocol for log collection"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 161
  to_port           = 162
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "smb_cifs" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Microsoft SMB/CIFS over TCP with NetBIOS framing"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS mount"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 635
  to_port           = 635
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS mount"
//  cidr_ipv4         = "10.0.0.0/8"
//  referenced_security_group_id = "sg-11111111111111111"
  from_port         = 635
  to_port           = 635
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.fsx_sg.id
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
  subnet_ids          = [var.fsx_subnets["primarysub"]]
  preferred_subnet_id = var.fsx_subnets["primarysub"]

// OPTIONAL PARAMETERS
  storage_capacity    = var.fsx_capacity_size_gb
  security_group_ids  = [aws_security_group.fsx_sg.id]
  deployment_type     = var.fsx_deploy_type
  throughput_capacity = var.fsx_tput_in_MBps
  tags = {
	  Name = var.fsx_name
  }
  # weekly_maintenance_start_time = "00:00:00"
  # kms_key_id = ""
  # automatic_backup_retention_days = 0
  # daily_automatic_backup_start_time = "00:00"
  # disk_iops_configuration = ""
  # endpoint_ip_address_range = ""
  # ha_pairs = 1
  # Storage_type = "SSD"
  # fsx_admin_password = ""
  # route_table_ids = []
  # throughput_capacity_per_ha_pair = 0
}

resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
// REQUIRED PARAMETERS
  file_system_id      = aws_fsx_ontap_file_system.terraform-fsxn.id
  name                = var.svm_name

// OPTIONAL PARAMETERS
  # root_volume_security_style = "UNIX"
  # tags = {}
  # active_directory_configuration {
  #   netbios_name = "mysvm"
  #   self_managed_active_directory_configuration {}
  # }
}

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
  # bypass_snaplock_enterprise_retention = true
  # copy_tags_to_backups = false
  # security_style = "MIXED"
  # skip_final_backup = false
  # snaplock_configuration {}
  # snapshot_policy {}
  # tags = {}  
}


