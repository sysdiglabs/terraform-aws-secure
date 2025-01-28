terraform {
  required_providers {
# TODO: testing only, update when TF provider is released
    sysdig = {
      source = "local/sysdiglabs/sysdig"
      version = "~> 1.0.0"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "https://secure-staging.sysdig.com"
  sysdig_secure_api_token =  "<API_TOKEN>"
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["123456789101"]
}

module "onboarding" {
  source            	    = "../../../modules/onboarding"
  organizational_unit_ids = ["ou-ks5g-dofso0kc"]
  is_organizational 	    = true
}

module "config-posture" {
  source                   = "../../../modules/config-posture"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  org_units                = ["ou-ks5g-dofso0kc"]
  is_organizational        = true
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture]
}