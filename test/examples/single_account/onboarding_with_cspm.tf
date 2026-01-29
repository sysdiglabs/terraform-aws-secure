terraform {
  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 3.3"
    }
  }
}

provider "sysdig" {
  sysdig_secure_url       = "https://secure-staging.sysdig.com"
  sysdig_secure_api_token = "<API_TOKEN>"
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["123456789101"]
}

module "onboarding" {
  source = "../../../modules/onboarding"
}

module "config-posture" {
  source                   = "../../../modules/config-posture"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
}

resource "sysdig_secure_cloud_auth_account_feature" "config_posture" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_CONFIG_POSTURE"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture]
}

resource "sysdig_secure_cloud_auth_account_feature" "identity_entitlement_basic" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_IDENTITY_ENTITLEMENT"
  enabled    = true
  components = [module.config-posture.config_posture_component_id]
  depends_on = [module.config-posture, sysdig_secure_cloud_auth_account_feature.config_posture]
  flags = {
    "CIEM_FEATURE_MODE" : "basic"
  }

  lifecycle {
    ignore_changes = [flags, components]
  }
}
