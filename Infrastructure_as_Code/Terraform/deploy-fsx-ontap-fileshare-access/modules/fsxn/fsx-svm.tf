resource "aws_fsx_ontap_storage_virtual_machine" "fsxsvm01" {
  file_system_id             = aws_fsx_ontap_file_system.fsx_ontap_fs.id
  name                       = "svm01"
  root_volume_security_style = var.fsxn_volume_security_style
  svm_admin_password         = var.fsxn_password

  active_directory_configuration {
    netbios_name = "FSxN-svm01"
    self_managed_active_directory_configuration {
      domain_name                            = var.ad.domain_name
      dns_ips                                = var.ad.dns_ips
      file_system_administrators_group       = var.ad.administrators_group
      organizational_unit_distinguished_name = var.ad.ou
      username                               = var.ad.service_account
      password                               = var.ad.service_account_password
    }
  }
}
