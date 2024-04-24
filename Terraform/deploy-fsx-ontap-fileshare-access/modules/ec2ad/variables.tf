variable "aws_location" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeeast-1"
}

variable "ec2_instance_name" {
  description = "EC2 Instance Name"
  type        = string
  default     = "Demo"
}

variable "ec2_instance_type" {
  description = "EC2 Instance Type for AD Server"
  type        = string
  default     = "t3.xlarge"
}

variable "ec2_iam_role" {
  description = "EC2 IAM Role with access to SSM Parameters"
  type        = string
  default     = "AWSIAM_ROLE_WITH_SSM_ACCESS"
}

variable "ad_domain" {
  description = "Active Directory Domain"
  type        = string
}

variable "ad_service_account" {
  description = "Active Directory Service Account"
  type        = string
  default     = "ec2ad_svc_account"
}

variable "ad_service_account_pwd" {
  description = "Active Directory Service Account Password"
  type        = string
  sensitive   = true
}

variable "ad_administrators_group" {
  description = "Active Directory new administrators group"
  type        = string
  default     = "FS Administrators Group"
}

variable "ec2_instance_key_pair" {
  description = "Name of the instance key pair"
  type        = string
}

variable "ec2_subnet_id" {
  description = "Subnet Id for EC2 Instances"
  type        = string
}

variable "security_groups_ids" {
  description = "Security Groups for EC2 Instances"
  type        = list(string)
}

variable "creator_tag" {
  description = "Tag with the Key as Creator"
  type        = string
}

variable "ssm_password_key" {
  description = "Password Variable Name in the SSM Document"
  type        = string
}
