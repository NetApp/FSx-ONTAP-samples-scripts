/*
 * The following defines a Security Group for FSx ONTAP that allows the required ports for NFS, CIFS,
 * Kerberos, and iSCSI as well as SnapMirror.
 *
 * While you don't have to use this SG, one will need to be assigned to the FSx ONTAP file system,
 * otherwise it won't be able to communicate with the clients.
 *
 * To not create the security group, set the variable create_sg to false in the variables.tf file.
 * Will will also need to set the security_group_id to the ID of the security group you want to use
 * in the variables.tf file.
 *
 */

locals {
  mycount = var.dr_create_sg ? 1 : 0
  my_ref_sec_group_id = (var.dr_source_sg_id != "" ? var.dr_source_sg_id : null)
  my_cidr      = (var.dr_cidr_for_sg != "" ? var.dr_cidr_for_sg : null)
}

resource "aws_security_group" "fsx_sg" {
  description = "Allow FSx ONTAP required ports"
  count       = local.mycount
  name_prefix = var.dr_security_group_name_prefix
  vpc_id      = var.dr_vpc_id
}

# locals {
#   my_security_group_id = aws_security_group.fsx_sg[count.index].id
# }

resource "aws_vpc_security_group_ingress_rule" "all_icmp" {
  description       = "Allow all ICMP traffic"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_tcp" {
  description       = "Remote procedure call for NFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 111
  to_port           = 111
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_udp" {
  description       = "Remote procedure call for NFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 111
  to_port           = 111
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "cifs" {
  description       = "NetBIOS service session for CIFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 139
  to_port           = 139
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_tcp" {
  description       = "Simple network management protocol for log collection"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 161
  to_port           = 162
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_udp" {
  description       = "Simple network management protocol for log collection"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 161
  to_port           = 162
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "smb_cifs" {
  description       = "Microsoft SMB/CIFS over TCP with NetBIOS framing"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_tcp" {
  description       = "NFS mount"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 635
  to_port           = 635
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kerberos" {
  description       = "Kerberos authentication"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 749
  to_port           = 749
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon" {
  description       = "NFS server daemon"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon_udp" {
  description       = "NFS server daemon"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon" {
  description       = "NFS lock daemon"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon_udp" {
  description       = "NFS lock daemon"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor" {
  description       = "Status monitor for NFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor_udp" {
  description       = "Status monitor for NFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_rquotad" {
  description       = "Remote quota server for NFS"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 4049
  to_port           = 4049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "iscsi_tcp" {
  description       = "iSCSI"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 3260
  to_port           = 3260
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_Intercluster_communication" {
  description       = "Snapmirror Intercluster communication"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 11104
  to_port           = 11104
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_data_transfer" {
  description       = "Snapmirror data transfer"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 11105
  to_port           = 11105
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_udp" {
  description       = "NFS mount"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 635
  to_port           = 635
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  description       = "ssh"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "s3_and_api" {
  description       = "Provice acccess to S3 and the ONTAP REST API"
  count             = local.mycount
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = local.my_cidr
  referenced_security_group_id = local.my_ref_sec_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  count             = local.mycount
  description       = "Allow all out bound traffic"
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
