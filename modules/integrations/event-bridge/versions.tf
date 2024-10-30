terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
    sysdig = {
      source  = "local/sysdiglabs/sysdig" // TODO: remove after test
      version = "~> 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
