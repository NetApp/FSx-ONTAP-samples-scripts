variable "prime_hostname" {
   description = "Hostname or IP address of primary cluster."
   type        = string
   default     = ""
}

variable "prime_fsxid" {
   description = "FSx ID of the primary cluster."
   type        = string
   default     = ""
}

variable "prime_clus_name" {
   description = "This is the name of the cluster given for ONTAP TF connection profile. This is a user creatred value, that can be any string. It is referenced in many ONTAP TF resources."
   type        = string
   default     = "primary_clus"
}

variable "prime_svm" {
   description = "Name of svm for replication in the primary cluster."
   type        = string
   default     = ""
}

variable "prime_cluster_vserver" {
   description = "Name of cluster vserver for inter cluster lifs in the primary cluster. This can be found by running network interface show on the source cluster. It will be formatted like this FsxIdxxxxxxxx"
   type        = string
   default     = ""
}

variable "prime_aws_region" {
   description = "AWS regionfor the Primary ONTAP FSxN"
   type        = string
   default     = ""
}

variable "username_pass_secrets_id" {
   description = "Name of secret ID in AWS secrets"
   type        = string
   default     = ""
}

variable "list_of_volumes_to_replicate" {
   description = "list of volumes to replicate to dr fsxn"
   type        = list(string)
   default     = []
}

variable "validate_certs" {
   description = "Do we validate the cluster certs (true or false)"
   type        = string
   default     = "false"
}
