/* 
 * The following defines a Security Group for FSx ONTAP that allows the required ports for
 * the NFS, CIFS, Kerberos, s3, and iSCSI protocols as well as for SnapMirror, ONTAP API
 * and ssh for the source cidr OR the source security group provided in the variables.tf file.
 *
 * While you don't have to use this SG, one will need to be assigned to the FSx ONTAP file system,
 * otherwise it won't be able to communicate with the clients.
 *
 * - If you wish to skip this resource, set the "create_sg" variable to false and set
 *   the "security_group_id" to the security group you want to use. Both of these variables
 *   can be found in the variables.tf file.
 *
 * - If you wish to use the created Security Group, just be sure to set the cidr_for_sg OR
 *   source_sg_id varaibles in the variables.tf file. Do not set both or the
 *   creation of the security group will fail.
 */

resource "aws_security_group" "fsx_sg" {
  description = "Allow FSx ONTAP required ports"
  count       = var.create_sg ? 1 : 0
  name_prefix = var.security_group_name_prefix
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "all_icmp" {
  description       = "Allow ICMP traffic"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = var.cidr_for_sg != "" ? var.cidr_for_sg : null
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_tcp" {
  description       = "Remote procedure call for NFS"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 111
  to_port           = 111
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_udp" {
  description       = "Remote procedure call for NFS"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 111
  to_port           = 111
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "cifs" {
  description       = "NetBIOS service session for CIFS"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 139
  to_port           = 139
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_tcp" {
  description       = "Simple network management protocol for log collection"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 161
  to_port           = 162
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_udp" {
  description       = "Simple network management protocol for log collection"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 161
  to_port           = 162
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "smb_cifs" {
  description       = "Microsoft SMB/CIFS over TCP with NetBIOS framing"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_tcp" {
  description       = "NFS mount"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 635
  to_port           = 635
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kerberos" {
  description       = "Kerberos authentication"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 749
  to_port           = 749
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon" {
  description       = "NFS server daemon"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon_udp" {
  description       = "NFS server daemon"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon" {
  description       = "NFS lock daemon"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon_udp" {
  description       = "NFS lock daemon"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor" {
  description       = "Status monitor for NFS"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor_udp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Status monitor for NFS"
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_rquotad" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "Remote quota server for NFS"
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 4049
  to_port           = 4049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "iscsi_tcp" {
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  description       = "iSCSI"
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 3260
  to_port           = 3260
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_Intercluster_communication" {
  description       = "Snapmirror Intercluster communication"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 11104
  to_port           = 11104
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_data_transfer" {
  description       = "Snapmirror data transfer"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 11105
  to_port           = 11105
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_udp" {
  description       = "NFS mount"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 635
  to_port           = 635
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  description       = "ssh"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "s3_and_api" {
  description       = "Provice acccess to S3 and the ONTAP REST API"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = (var.cidr_for_sg != "" ? var.cidr_for_sg : null)
  referenced_security_group_id = (var.source_sg_id != "" ? var.source_sg_id : null)
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  description       = "Allow all outbound traffic"
  count             = var.create_sg ? 1 : 0
  security_group_id = aws_security_group.fsx_sg[count.index].id
  cidr_ipv4         = "0.0.0.0/0"  // Allow all output traffic.
  ip_protocol       = "-1"
}
