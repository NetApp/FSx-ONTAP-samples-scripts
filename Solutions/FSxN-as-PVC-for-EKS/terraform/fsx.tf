#
# Generate a random password for FSx
resource "random_string" "fsx_password" {
  length           = 8
  min_lower        = 1
  min_numeric      = 1
  min_special      = 0
  min_upper        = 1
  number           = true
  special          = true
  override_special = "@$%^&*()_+="
}
#
# Store the password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "fsx_secret_password" {
 name = var.fsx_password_secret_name
}
#
resource "aws_secretsmanager_secret_version" "fsx_secret_password" {
  secret_id = aws_secretsmanager_secret.fsx_secret_password.id
  secret_string =  jsonencode({username = "fsxadmin", password = random_string.fsx_password.result})
}

resource "aws_fsx_ontap_file_system" "eksfs" {
  storage_capacity    = var.fsxn_storage_capacity
  subnet_ids          = module.vpc.private_subnets
  deployment_type     = "MULTI_AZ_1"
  throughput_capacity = var.fsxn_throughput_capacity
  preferred_subnet_id = module.vpc.private_subnets[0]
  security_group_ids  = [aws_security_group.fsx_sg.id]
  fsx_admin_password = random_string.fsx_password.result
  route_table_ids    = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
  tags = {
    Name = var.fsx_name
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "ekssvm" {
  file_system_id = aws_fsx_ontap_file_system.eksfs.id
  name           = "ekssvm"
}

resource "aws_security_group" "fsx_sg" {
  name_prefix = "security group for fsx access"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "fsx_sg"
  }
}
#
# Allow 'ssh' from jump server based on its security group since will be in the public subnet.
resource "aws_security_group_rule" "fsx_sg_ssh_from_jump_server" {
  description       = "allow ssh from jump_server to fsx"
  from_port         = 0
  protocol          = "tcp"
  to_port           = 22
  security_group_id = aws_security_group.fsx_sg.id
  type              = "ingress"
  source_security_group_id = aws_security_group.eks_jump_server.id
}
#
# Allow allow traffic from the private subnets.
resource "aws_security_group_rule" "fsx_sg_inbound" {
  description       = "allow inbound traffic to eks"
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  security_group_id = aws_security_group.fsx_sg.id
  type              = "ingress"
#  cidr_blocks       = [var.vpc_cidr]
  cidr_blocks       = module.vpc.private_subnets_cidr_blocks
}

resource "aws_security_group_rule" "fsx_sg_outbound" {
  description       = "allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.fsx_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
