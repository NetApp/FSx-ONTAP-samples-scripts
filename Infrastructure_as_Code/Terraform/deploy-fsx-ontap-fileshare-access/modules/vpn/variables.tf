variable "server_cert" {
  description = ""
  type        = string
}

variable "server_private_key" {
  description = ""
  type        = string
}

variable "client_cert" {
  description = ""
  type        = string
}

variable "client_private_key" {
  description = ""
  type        = string
}

variable "ca_crt" {
  description = ""
  type        = string
}

variable "vpc_id" {
  description = ""
  type        = string
}

variable "vpn_cidr" {
  description = ""
  type        = string
  default     = "10.100.0.0/22"
}

variable "public_subnet_id" {
  description = ""
  type        = string
}
