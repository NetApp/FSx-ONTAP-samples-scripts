
terraform {
  required_version = ">= 0.12"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.23.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.25.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.2"
    }
  }
}
