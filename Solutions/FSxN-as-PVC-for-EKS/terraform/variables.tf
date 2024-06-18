variable "aws_region" {
  default = "us-west-2"
  description = "aws region where you want the resources deployed."
}

variable "fsx_name" {
  default     = "eksfs"
  description = "The name you want assigned to the FSxN file system."
}

variable "fsx_password_secret_name" {
  default     = "fsx-eks-secret"
  description = "The basename of the secret to create within the AWS Secrets Manager that will contain the FSxN password. A random string will be appended to the end of the secreate name to ensure no name conflict."
}

variable "aws_secrets_region" {
  default     = "us-west-2"
  description = "The region where you want the secret stored within AWS Secrets Manager."
}

variable "trident_version" {
  default     = "v24.2.0-eksbuild.1"
  description = "The version of Astra Trident to 'add-on' to the EKS cluster."
}

variable "fsxn_throughput_capacity" {
  default = 128
  description = "The throughput capacity to be allocated to the FSxN cluster. Must be 128, 256, 512, 1024, 2048, 4096."
}

variable "fsxn_storage_capacity" {
  default = 1024
  description = "The storage capacity, in GiBs, to be allocated to the FSxN clsuter. Must be at least 1024, and less than 196608."
}
#
# Keep in mind that key pairs are regional, so pick one that is in the region specified above.
variable "key_pair_name" {
  default = "MUST REPLACE WITH YOUR KEY PAIR NAME"
  description = "The key pair to associate with the jump server."
}

variable "secure_ips" {
  default = ["0.0.0.0/0"]
  description = "List of CIDRs that are allowed to ssh into the jump server."
}

################################################################################
# Don't change any variables below this line.
################################################################################

variable "kubernetes_version" {
  default     = 1.29
  description = "kubernetes version"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "default CIDR range of the VPC"
}
