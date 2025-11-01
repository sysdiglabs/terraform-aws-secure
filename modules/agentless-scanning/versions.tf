terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    sysdig = {
      source = "sysdiglabs/sysdig"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
