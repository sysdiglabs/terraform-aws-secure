#---------------------------------------------------------------------------------------------
# Ensure installation flow for foundational onboarding has been completed before
# installing additional Sysdig features.
#---------------------------------------------------------------------------------------------

module "event-bridge" {
  source                   = "../../../modules/integrations/event-bridge"
  regions                  = ["us-gov-east-1"]
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = module.onboarding.is_organizational
  is_gov_cloud_onboarding  = module.onboarding.is_gov_cloud_onboarding

  # include/exclude org install params
  include_ouids    = module.onboarding.include_ouids
  exclude_ouids    = module.onboarding.exclude_ouids
  include_accounts = module.onboarding.include_accounts
  exclude_accounts = module.onboarding.exclude_accounts
}

resource "sysdig_secure_cloud_auth_account_feature" "threat_detection" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_THREAT_DETECTION"
  enabled    = true
  components = [module.event-bridge.event_bridge_component_id]
  depends_on = [module.event-bridge]
}

resource "sysdig_secure_cloud_auth_account_feature" "identity_entitlement_advanced" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_IDENTITY_ENTITLEMENT"
  enabled    = true
  components = concat(sysdig_secure_cloud_auth_account_feature.identity_entitlement_basic.components, [module.event-bridge.event_bridge_component_id])
  depends_on = [module.event-bridge]
  flags      = { "CIEM_FEATURE_MODE" : "advanced" }

  lifecycle {
    ignore_changes = [flags, components]
  }
}
