variable "prime_hostname" {
   description = "Hostname or IP address of primary cluster."
   type        = string
# Development FSxN
   default     = "198.19.253.210"
}

variable "prime_svm" {
   description = "Name of svm for replication in the primary cluster."
   type        = string
   default     = "vs1cli"
}

variable "secrets_aws_region" {
   description = "Region where the AWS secret for username/password reside"
   type        = string
   default     = "us-west-2"
}

variable "username_pass_secrets_id" {
   description = "Name of secret ID in AWS secrets"
   type        = string
   default     = "rvwn_replicate_ontap_creds"
}

variable "list_of_volumes_to_replicate" {
   description = "list of volumes to replicate to dr fsxn"
   type        = list(string)
   default     = ["cifs_share", "rvwn_from_bxp", "unix"]
}

variable "dr_username_pass_secrets_id" {
   description = "Name of secret ID in AWS secrets"
   type        = string
   default     = "rvwn_replicate_ontap_creds"
}

variable "dr_hostname" {
   description = "Hostname or IP address of disaster recovery cluster."
   type        = string
# Prod DR FSxN
   default     = "198.19.254.83"
}

variable "validate_certs" {
   description = "Do we validate the cluster certs (true or false)"
   type        = string
   default     = "false"
}