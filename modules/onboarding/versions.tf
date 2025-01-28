terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    # TODO: testing only, update when TF provider is released
    sysdig = {
      source = "local/sysdiglabs/sysdig"
      version = "~> 1.0.0"
    }
  }
}

