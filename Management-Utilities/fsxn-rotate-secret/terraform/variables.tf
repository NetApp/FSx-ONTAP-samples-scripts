variable "secret_region" {
  description = "The AWS region where the new secret will be created."
  type        = string
}

variable "fsx_region" {
  description = "The AWS region where the FSxN file system resides."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID. Use to create very specific permissions."
  type        = string
}

variable "secret_name_prefix" {
  description = "The prefix to the secret name that will be created that will contain the password. A random nmumber will be appended to the end of the prefix to ensure no conflict will exist with an existing secret."
  type        = string
  default     = "fsxn-secret"
}

variable "fsx_id" {
  description = "The FSxN file system ID of the file system that you want to rotate the password on."
  type        = string
  default     = ""
}

variable "svm_id" {
  description = "The SVM ID of the SVM that you want to rotate the password on."
  type        = string
  default     = ""
}

variable "rotation_frequency" {
  description = "The rotation frequency of the secret. It should express in AWS's rate() or cron() format. The default is once every 30 days."
  type        = string
  default     = "rate(30 days)"
}
