terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = [aws.sns]
    }
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.56"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
