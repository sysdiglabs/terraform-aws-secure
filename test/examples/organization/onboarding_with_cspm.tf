terraform {
  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 1.47"
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
  is_organizational         = true
  # legacy org install
  # organizational_unit_ids = ["ou-ks5g-dofso0kc"]

  # include/exclude params
  include_ouids = ["ou-1", "ou-2"]
  exclude_accounts = ["123456789101", "123456789101", "123456789101", "123456789101"]
  include_accounts = ["123456789101", "123456789101"]
}

module "config-posture" {
  source                   = "../../../modules/config-posture"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = true
  # legacy org install
  # org_units               = ["ou-ks5g-dofso0kc"]

  # include/exclude params
  include_ouids = module.onboarding.include_ouids
  exclude_ouids = module.onboarding.exclude_ouids
  include_accounts = module.onboarding.include_accounts
  exclude_accounts = module.onboarding.exclude_accounts
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture]
}
