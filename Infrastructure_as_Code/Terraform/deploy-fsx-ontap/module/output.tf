output "security_group_id" {
  description = "The ID of the FSxN Security Group"
  value       = var.create_sg ? [element(aws_security_group.fsx_sg[*].id, 0)] : []
}

output "filesystem_id" {
  description = "The ID of the FSxN Filesystem"
  value       = aws_fsx_ontap_file_system.terraform-fsxn.id
}

output "svm_id" {
  description = "The ID of the FSxN Storage Virtual Machine"
  value       = aws_fsx_ontap_storage_virtual_machine.mysvm.id
}

output "vol_id" {
  description = "The ID of the ONTAP volume in the File System"
  value       = aws_fsx_ontap_volume.myvol.id
}

output "fsxn_secret_arn" {
  description = "The ARN of the secret"
  value       = module.fsxn_rotate_secret.secret_arn
}

output "fsxn_secret_name" {
  description = "The Name of the secret"
  value       = module.fsxn_rotate_secret.secret_name
}

output "svm_secret_arn" {
  description = "The Name of the secret"
  value       = module.svm_rotate_secret.secret_arn
}

output "svm_secret_name" {
  description = "The Name of the secret"
  value       = module.svm_rotate_secret.secret_name
}

output "filesystem_management_ip" {
  description = "The management IP of the FSxN Filesystem."
  value       =  format(join("", aws_fsx_ontap_file_system.terraform-fsxn.endpoints[0].management[0].ip_addresses))
}

output "svm_management_ip" {
  description = "The management IP of the Storage Virtual Machine."
  value       =  format(join("", aws_fsx_ontap_storage_virtual_machine.mysvm.endpoints[0].management[0].ip_addresses))
}
