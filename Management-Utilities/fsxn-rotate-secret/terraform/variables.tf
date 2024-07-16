variable "region" {
  description = "The AWS region where the FSxN file system resides."
  type        = string
}

variable "awsAccountId" {
  description = "The AWS account ID."
  type        = string
}

variable "secretNamePrefix" {
  description = "The prefix to the secret name that will be created that will contain the FSxN file system's password."
  type        = string
}

variable "fsxId" {
  description = "The FSxN file system ID."
  type        = string
}

variable "rotationFrequency" {
  description = "The rotation frequency of the secret. It should express in AWS's rate() or cron() format. The default is once every 30 days."
  type        = string
  default     = "rate(30 days)"
}
