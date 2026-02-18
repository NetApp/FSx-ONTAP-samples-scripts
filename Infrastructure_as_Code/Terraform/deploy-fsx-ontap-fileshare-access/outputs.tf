output "FSxN_Management_IP" {
  description = "FSxN Management IP"
  value       = module.fsxontap.fsxn_management_management_ip
}

output "MicrosoftAD_Server_Private_IP" {
  description = "FSxN SQL Serer Private and Public IP addresses"
  value       = module.ec2-ad.ip_address.private_ip
}

output "FSxN_File_System_ID" {
  value = module.fsxontap.fsxn_file_system.id
}

output "FSxN_SVM_ID" {
  value = module.fsxontap.fsxn_svm.id
}

output "FSxN_SVM_SMB_Endpoint" {
  value = module.fsxontap.fsxn_svm.endpoints[0].smb[0]
}

output "FSxN_SVM_NFS_Endpoint" {
  value = module.fsxontap.fsxn_svm.endpoints[0].nfs[0]
}

output "FSxN_Volume_1" {
  value = {
    id   = module.fsxontap.fsxn_volume_1.id
    name = module.fsxontap.fsxn_volume_1.name
  }
}

output "FSxN_Volume_2" {
  value = {
    id   = module.fsxontap.fsxn_volume_2.id
    name = module.fsxontap.fsxn_volume_2.name
  }
}
