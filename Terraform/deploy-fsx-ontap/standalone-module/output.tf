output "my_fsx_ontap_security_group_id" {
  description = "The ID of the FSxN Security Group"
  value       = join(", ", aws_fsx_ontap_file_system.terraform-fsxn.security_group_ids)
}

output "my_filesystem_id" {
  description = "The ID of the FSxN Filesystem"
  value       = aws_fsx_ontap_file_system.terraform-fsxn.id
}

output "my_filesystem_management_ip" {
  description = "The management IP of the FSxN Filesystem."
  value       =  join("", aws_fsx_ontap_file_system.terraform-fsxn.endpoints[0].management[0].ip_addresses)
}

output "my_svm_id" {
  description = "The ID of the FSxN Storage Virtual Machine"
  value       = aws_fsx_ontap_storage_virtual_machine.mysvm.id
}

output "my_svm_management_ip" {
  description = "The management IP of the Storage Virtual Machine."
  value       =  join("", aws_fsx_ontap_storage_virtual_machine.mysvm.endpoints[0].management[0].ip_addresses)
}

output "my_vol_id" {
  description = "The ID of the ONTAP volume in the File System"
  value       = aws_fsx_ontap_volume.myvol.id
}

output "my_fsxn_secret_name" {
  description = "The name of the secret containing the ONTAP admin password"
  value       = module.fsxn_rotate_secret.secret_name
}

output "my_svm_secret_name" {
  description = "The name of the secret containing the SVM admin password"
  value       = module.svm_rotate_secret.secret_name
}
