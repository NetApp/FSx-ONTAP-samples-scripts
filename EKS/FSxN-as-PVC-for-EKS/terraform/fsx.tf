#
# Instantiate an AWS secret for the FSx ONTAP file system. It will set the initial password for the file system.
module "fsxn_rotate_secret" {
    source = "github.com/Netapp/FSx-ONTAP-samples-scripts/Management-Utilities/fsxn-rotate-secret/terraform"
    fsx_region = var.aws_region
    secret_region = var.aws_secrets_region
    aws_account_id = data.aws_caller_identity.current.account_id
    secret_name_prefix = var.secret_name_prefix
    fsx_id = aws_fsx_ontap_file_system.eksfs.id
}
#
# Create a FSxN file system.
resource "aws_fsx_ontap_file_system" "eksfs" {
  storage_capacity    = var.fsxn_storage_capacity
  subnet_ids          = module.vpc.private_subnets
  deployment_type     = "MULTI_AZ_1"
  throughput_capacity = var.fsxn_throughput_capacity
  preferred_subnet_id = module.vpc.private_subnets[0]
  security_group_ids  = [aws_security_group.fsx_sg.id]
  route_table_ids     = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
  tags = {
    Name = var.fsx_name
  }
}
#
# Instantiate an AWS secret for the storage virtual machine. It will set the initial password for the SVM.
module "svm_rotate_secret" {
    source = "github.com/Netapp/FSx-ONTAP-samples-scripts/Management-Utilities/fsxn-rotate-secret/terraform"
    fsx_region = var.aws_region
    secret_region = var.aws_secrets_region
    aws_account_id = data.aws_caller_identity.current.account_id
    secret_name_prefix = var.secret_name_prefix
    svm_id = aws_fsx_ontap_storage_virtual_machine.ekssvm.id
}
#
# Create a vserver and assign the 'vsadmin' the same password as fsxadmin.
resource "aws_fsx_ontap_storage_virtual_machine" "ekssvm" {
  file_system_id = aws_fsx_ontap_file_system.eksfs.id
  name           = "ekssvm"
}
