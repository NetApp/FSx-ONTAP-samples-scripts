output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "fsx-password-secret-name" {
   value = aws_secretsmanager_secret.fsx_secret_password.name
}

output "fsx-password-secret-arn" {
  value = aws_secretsmanager_secret_version.fsx_secret_password.arn
}

output "fsx-svm-name" {
  value = aws_fsx_ontap_storage_virtual_machine.ekssvm.name
}

output "fsx-id" {
  value = aws_fsx_ontap_file_system.eksfs.id
}

output "fsx-management-ip" {
  value = format(join("", aws_fsx_ontap_file_system.eksfs.endpoints[0].management[0].ip_addresses))
}

output "eks-cluster-name" {
  value = module.eks.cluster_name
}

output "vpc-id" {
  value = module.vpc.vpc_id
}

output "eks-jump-server" {
  value = format("Instance ID: %s, Public IP: %s", aws_instance.eks_jump_server.id, aws_instance.eks_jump_server.public_ip)
}
