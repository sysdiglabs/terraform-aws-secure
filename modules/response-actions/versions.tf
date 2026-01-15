terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    sysdig = {
      source  = "sysdiglabs/sysdig"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}
