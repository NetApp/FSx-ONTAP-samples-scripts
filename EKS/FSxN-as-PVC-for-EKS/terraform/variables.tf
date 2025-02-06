variable "aws_region" {
  description = "The AWS region where you want the resources deployed."
  type        = string
}

variable "aws_secrets_region" {
  description = "The AWS region where you want the FSxN and SVM secrets stored within AWS Secrets Manager."
  type        = string
}

variable "fsx_name" {
  description = "The name you want assigned to the FSxN file system."
  default     = "eksfs"
}

variable "secret_name_prefix" {
  description = "The base name of the secrets (FSxN and SVM) to create within the AWS Secrets Manager. A random string will be appended to the end of the secreate name to ensure no name conflict."
  default     = "fsx-eks-secret"
}

variable "fsxn_storage_capacity" {
  description = "The storage capacity, in GiBs, to be allocated to the FSxN clsuter. Must be at least 1024, and less than 196608."
  type        = number
  default     = 1024
  validation {
    condition = var.fsxn_storage_capacity >= 1024 && var.fsxn_storage_capacity < 196608
    error_message = "The storage capacity must be at least 1024, and less than 196608."
  }
}

variable "fsxn_throughput_capacity" {
  description = "The throughput capacity to be allocated to the FSxN cluster. Must be 128, 256, 512, 1024, 2048, 4096."
  type        = string   # Set to a string so it can be used in a "contains()" function.
  default     = "128"
  validation {
    condition = contains(["128", "256", "512", "1024", "2048", "4096"], var.fsxn_throughput_capacity)
    error_message = "The throughput capacity must be 128, 256, 512, 1024, 2048, or 4096."
  }
}
#
# Keep in mind that key pairs are regional, so pick one that is in the region specified above.
variable "key_pair_name" {
  description = "The key pair to associate with the jump server."
  default     = "MUST REPLACE WITH YOUR KEY PAIR NAME"
  type        = string
  validation {
    condition = var.key_pair_name != "MUST REPLACE WITH YOUR KEY PAIR NAME"
    error_message = "You must specify a key pair name."
  }
}

variable "secure_ips" {
  description = "List of CIDRs that are allowed to ssh into the jump server."
  default = ["0.0.0.0/0"]
}

################################################################################
# Don't change any variables below this line.
################################################################################

variable "trident_version" {
  description = "The version of Astra Trident to 'add-on' to the EKS cluster."
  default     = "v24.10.0-eksbuild.1"
  type        = string
}

variable "kubernetes_version" {
  description = "kubernetes version"
  default     = 1.31
  type        = string
}

variable "vpc_cidr" {
  description = "default CIDR range of the VPC"
  default     = "10.0.0.0/16"
  type        = string
}
