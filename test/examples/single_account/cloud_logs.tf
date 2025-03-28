#---------------------------------------------------------------------------------------------
# Ensure installation flow for foundational onboarding has been completed before
# installing additional Sysdig features.
#---------------------------------------------------------------------------------------------

module "cloud-logs" {
  source                   = "../../../modules/integrations/cloud-logs"
  folder_arn               = "<FOLDER_ARN"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
}

resource "sysdig_secure_cloud_auth_account_feature" "threat_detection" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_THREAT_DETECTION"
  enabled    = true
  components = [module.cloud-logs.cloud_logs_component_id]
  depends_on = [module.cloud-logs]
}

resource "sysdig_secure_cloud_auth_account_feature" "identity_entitlement_advanced" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_IDENTITY_ENTITLEMENT"
  enabled    = true
  components = concat(sysdig_secure_cloud_auth_account_feature.identity_entitlement_basic.components, [module.cloud-logs.cloud_logs_component_id])
  depends_on = [module.cloud-logs, sysdig_secure_cloud_auth_account_feature.identity_entitlement_basic]
  flags = {"CIEM_FEATURE_MODE": "advanced"}
}
