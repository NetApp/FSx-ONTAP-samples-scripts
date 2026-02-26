output "FSxN_management_ip" {
  description = "FSxN Management IP"
  value       = module.fsxontap.fsx_management_management_ip
}

output "FSxN_svm_iscsi_endpoints" {
  description = "FSxN SVM iSCSI endpoints"
  value       = module.fsxontap.fsx_svm_iscsi_endpoints
}

output "FSxN_sql_server_ip" {
  description = "FSxN SQL Serer Private and Public IP addresses"
  value       = module.sqlserver.ip_address
}

output "FSxN_file_system_id" {
  value = module.fsxontap.fsx_file_system.id
}

output "FSxN_svm_id" {
  value = module.fsxontap.fsx_svm.id
}

output "FSxN_sql_data_volume" {
  value = {
    id   = module.fsxontap.fsx_sql_data_volume.id
    name = module.fsxontap.fsx_sql_data_volume.name
  }
}

output "FSxN_sql_log_volume" {
  value = {
    id   = module.fsxontap.fsx_sql_log_volume.id
    name = module.fsxontap.fsx_sql_log_volume.name
  }
}
