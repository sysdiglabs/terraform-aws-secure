provider "aws" {
  region = "us-east-1"
}

provider "sysdig" {
  sysdig_secure_url       = "https://secure-staging.sysdig.com"
  sysdig_secure_api_token = "<API_TOKEN>"
}

terraform {
  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.28"
    }
  }
}

module "onboarding" {
  source            	  = "../../../modules/onboarding"
  trusted_identity  	  = "arn:aws:iam::064689838359:role/us-east-1-integration01-secure-assume-role"
  external_id       	  = "81145517f4fafde4ade30b01762b7b0b"
  organizational_unit_ids = []
  is_organizational 	  = true
}

module "config-posture" {
  source            = "../../../modules/config-posture"
  trusted_identity  = "arn:aws:iam::064689838359:role/us-east-1-integration01-secure-assume-role"
  external_id       = "81145517f4fafde4ade30b01762b7b0b"
  role_name         = "sysdig-secure-2u6g"
  org_units         = [module.onboarding.organizational_unit_ids]
  is_organizational = true
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture]
}