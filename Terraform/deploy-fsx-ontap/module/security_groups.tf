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
 * - If you wish to use the created Security Group, just be sure to set the cidr_block OR
 *   source_security_group_id varaibles in the variables.tf file. Do not set both or the
 *   creation of the security group will fail.
 */

resource "aws_security_group" "fsx_sg" {
  name        = "fsx_sg"
  description = "Allow FSx ONTAP required ports"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "all_icmp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Allow all ICMP traffic"
  cidr_ipv4         = "0.0.0.0/0"   // Allowing all ICMP traffic from all sources
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Remote procedure call for NFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 111
  to_port           = 111
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Remote procedure call for NFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 111
  to_port           = 111
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "cifs" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NetBIOS service session for CIFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 139
  to_port           = 139
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Simple network management protocol for log collection"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 161
  to_port           = 162
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "snmp_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Simple network management protocol for log collection"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 161
  to_port           = 162
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "smb_cifs" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Microsoft SMB/CIFS over TCP with NetBIOS framing"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS mount"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 635
  to_port           = 635
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kerberos" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Kerberos authentication"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 749
  to_port           = 749
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS server daemon"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_server_daemon_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS server daemon"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS lock daemon"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_lock_daemon_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS lock daemon"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 4045
  to_port           = 4045
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Status monitor for NFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_status_monitor_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Status monitor for NFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 4046
  to_port           = 4046
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_rquotad" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Remote quota server for NFS"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 4049
  to_port           = 4049
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "iscsi_tcp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "iSCSI"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 3260
  to_port           = 3260
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_Intercluster_communication" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Snapmirror Intercluster communication"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 11104
  to_port           = 11104
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "Snapmirror_data_transfer" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Snapmirror data transfer"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 11105
  to_port           = 11105
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_mount_udp" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "NFS mount"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 635
  to_port           = 635
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "ssh"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "s3_and_api" {
  security_group_id = aws_security_group.fsx_sg.id
  description       = "Provice acccess to S3 and the ONTAP REST API"
  cidr_ipv4         = (var.cidr_block != "" ? var.cidr_block : null)
  referenced_security_group_id = (var.source_security_group_id != "" ? var.source_security_group_id : null)
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.fsx_sg.id
  cidr_ipv4         = "0.0.0.0/0"  // Allow all output traffic.
  ip_protocol       = "-1"
}
