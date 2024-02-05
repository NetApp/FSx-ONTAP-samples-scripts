output "my_fsx_ontap_security_group_id" {
  description = "The ID of the FSxN Security Group"
  value       = var.create_sg ? [element(aws_security_group.fsx_sg.*.id, 0)] : []
}

output "my_filesystem_id" {
  description = "The ID of the FSxN Filesystem"
  value       = aws_fsx_ontap_file_system.terraform-fsxn.id
}

output "my_svm_id" {
  description = "The ID of the FSxN Storage Virtual Machine"
  value       = aws_fsx_ontap_storage_virtual_machine.mysvm.id
}

output "my_vol_id" {
  description = "The ID of the ONTAP volume in the File System"
  value       = aws_fsx_ontap_volume.myvol.id
}