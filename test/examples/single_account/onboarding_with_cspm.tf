provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "https://secure-staging.sysdig.com"
  sysdig_secure_api_token =  "<API_TOKEN>"
}

module "onboarding" {
  source            = "../../../modules/onboarding"
  trusted_identity  = "arn:aws:iam::064689838359:role/us-east-1-integration01-secure-assume-role"
  external_id       = "<EXTERNAL_ID>"
}

module "config-posture" {
  source           = "../../../modules/config-posture"
  role_name        = "sysdig-secure-r1bn"
  trusted_identity = "arn:aws:iam::064689838359:role/us-east-1-integration01-secure-assume-role"
  external_id      = "<EXTERNAL_ID>"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture]
}