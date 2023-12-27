output "my_filesystem_id" {
  description = "The ID of the FSxN Filesystem"
  value       = aws_fsx_ontap_file_system.rvwn-terra-fsxn.id
}

output "my_svm_id" {
  description = "The ID of the FSxN Storage Virtual Machine"
  value       = aws_fsx_ontap_storage_virtual_machine.mysvm.id
}

