terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.48"
    }
  }
}
