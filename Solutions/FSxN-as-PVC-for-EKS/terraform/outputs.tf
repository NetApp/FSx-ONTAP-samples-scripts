output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "fsx-management-ip" {
  value = join("", aws_fsx_ontap_file_system.eksfs.endpoints[0].management[0].ip_addresses)
}

output "fsx-password-secret-name" {                                                                                                   value = var.fsx_password_secret_name
}

output "fsx-password-secret-arn" {
  value = aws_secretsmanager_secret_version.fsx_secret_password.arn
}

output "fsx-svm-name" {
  value = format("FSX_SVM_NAME=%s", aws_fsx_ontap_storage_virtual_machine.ekssvm.name)
}

output "fsx-svm-data-LIF" {
  value = join("", aws_fsx_ontap_storage_virtual_machine.ekssvm.endpoints[0].nfs[0].ip_addresses)
}

output "eks-cluster-name" {
  value = data.aws_eks_cluster.eks.id
}

output "vpc-id" {
  value = module.vpc.vpc_id
}

output "eks-jump-server" {
  value = format("Instance ID: %s, Public IP: %s", aws_instance.eks_jump_server.id, aws_instance.eks_jump_server.public_ip)
}

output "zz_update_kubeconfig_command" {
  value = format("%s %s %s %s", "aws eks update-kubeconfig --name", module.eks.cluster_name, "--region", var.aws_region)
}
