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
