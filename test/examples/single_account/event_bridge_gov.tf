#---------------------------------------------------------------------------------------------
# Ensure installation flow for foundational onboarding has been completed before
# installing additional Sysdig features.
#---------------------------------------------------------------------------------------------

module "event-bridge" {
  source                   = "../../../modules/integrations/event-bridge"
  regions                  = ["us-gov-east-1"]
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_gov_cloud             = module.onboarding.is_gov_cloud
}

resource "sysdig_secure_cloud_auth_account_feature" "threat_detection" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_THREAT_DETECTION"
  enabled    = true
  components = [module.event-bridge.event_bridge_component_id]
  depends_on = [module.event-bridge]
}

resource "sysdig_secure_cloud_auth_account_feature" "identity_entitlement" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_IDENTITY_ENTITLEMENT"
  enabled    = true
  components = [module.event-bridge.event_bridge_component_id]
  depends_on = [module.event-bridge, sysdig_secure_cloud_auth_account_feature.config_posture]
}
