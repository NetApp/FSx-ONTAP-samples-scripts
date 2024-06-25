#
# Generate a random password for FSx
resource "random_string" "fsx_password" {
  length           = 8
  min_lower        = 1
  min_numeric      = 1
  min_special      = 0
  min_upper        = 1
  numeric          = true
  special          = true
  override_special = "@$%^&*()_+="
}

provider "aws" {
  alias = "secrets_provider"
  region = var.aws_secrets_region
}
#
# Store the password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "fsx_secret_password" {
  provider = aws.secrets_provider
  name = "${var.fsx_password_secret_name}-${random_id.id.hex}"
}
resource "aws_secretsmanager_secret_version" "fsx_secret_password" {
  provider = aws.secrets_provider
  secret_id = aws_secretsmanager_secret.fsx_secret_password.id
  secret_string =  jsonencode({username = "vsadmin", password = random_string.fsx_password.result})
}
#
# Note that this allows traffic from both the private and public subnets. However
# the security groups only allow traffic from the public subnet over port 22 when
# the source has the jump server SG assigned to it. So, basically, it only allows traffic
# from the jump server from the public subnet.
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
#
# Create a vserver and assign the 'vsadmin' the same password as fsxadmin.
resource "aws_fsx_ontap_storage_virtual_machine" "ekssvm" {
  file_system_id = aws_fsx_ontap_file_system.eksfs.id
  name           = "ekssvm"
  svm_admin_password = random_string.fsx_password.result
}
