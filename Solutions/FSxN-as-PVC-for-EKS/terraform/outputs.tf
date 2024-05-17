output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "fsx-id" {
  value = format("FSX_ID=%s", aws_fsx_ontap_file_system.eksfs.id)
}

output "fsx-management-ip" {
  value = format("FSX_MANAGEMENT_IP=%s", join("", aws_fsx_ontap_file_system.eksfs.endpoints[0].management[0].ip_addresses))
}

output "fsx-password" {
  value = format("FSX_PASSWORD=%s", random_string.fsx_password.result)
}

output "fsx-svm-name" {
  value = format("FSX_SVM_NAME=%s", aws_fsx_ontap_storage_virtual_machine.ekssvm.name)
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
