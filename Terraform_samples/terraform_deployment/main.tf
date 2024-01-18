// TODO: add security group resource
// TODO: Include all possible parameters in the resource block
// TODO: Consider using aws secret manager resource to keep the created password string
// TODO: Consider making this a module


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
  The code below deploys a file system, a storage virtual machine, and a volume.
  Every resource include both optional and required parameters, separated by a comment line.
  Feel free to add or remove optional parameters as needed.
*/

resource "aws_fsx_ontap_file_system" "terraform-fsxn" {
  storage_capacity = var.fs_capacity_size_gb
  subnet_ids = var.vpc_idfsx_subnets["primarysub"]
  deployment_type = var.deploy_type
  throughput_capacity = var.fs_tput_in_MBps
  preferred_subnet_id = var.fsx_subnets["primarysub"]
  tags = {
	  Name = var.fs_nvar.vpc_id
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "mysvm" {
  file_system_id = aws_fsx_ontap_file_system.terraform-fsxn.id
  name           = var.svm_name
}

resource "aws_fsx_ontap_volume" "myvol" {
  name                       = var.vol_info["vol_name"]
  junction_path              = var.vol_info["junction_path"]
  size_in_megabytes          = var.vol_info["size_mg"]
  storage_efficiency_enabled = var.vol_info["efficiency"]
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.mysvm.id

  tiering_policy {
    name           = var.vol_info["tier_policy_name"]
    cooling_period = var.vol_info["cooling_period"]
  }
}


