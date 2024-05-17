resource "aws_security_group" "eks_jump_server" {
  name_prefix = "eks_jump_server"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "eks_jump_server_ingress" {
  description       = "Allow inbound ssh traffic from anywhere."
  from_port         = 0
  protocol          = "tcp"
  to_port           = 22
  security_group_id = aws_security_group.eks_jump_server.id
  type              = "ingress"
  cidr_blocks = var.secure_ips
}

resource "aws_security_group_rule" "eks_jump_server_egress" {
  description       = "Allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_jump_server.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "all_worker_mgmt_ingress" {
  description       = "allow inbound traffic from eks"
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  security_group_id = aws_security_group.all_worker_mgmt.id
  type              = "ingress"
  cidr_blocks = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]
}

resource "aws_security_group_rule" "all_worker_mgmt_egress" {
  description       = "allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.all_worker_mgmt.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
