#---------------------------------------------------------------------------------------------
# Ensure installation flow for foundational onboarding has been completed before
# installing additional Sysdig features.
#---------------------------------------------------------------------------------------------

module "agentless-scanning" {
  source                   = "../../../modules/agentless-scanning"
  regions                  = ["us-east-1", "us-west-1", "us-west-2"]
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = module.onboarding.is_organizational
  # legacy org install
  # org_units                = module.onboarding.organizational_unit_ids

  # include/exclude org install params
  include_ouids    = module.onboarding.include_ouids
  exclude_ouids    = module.onboarding.exclude_ouids
  include_accounts = module.onboarding.include_accounts
  exclude_accounts = module.onboarding.exclude_accounts
}

resource "sysdig_secure_cloud_auth_account_feature" "agentless_scanning" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_AGENTLESS_SCANNING"
  enabled    = true
  components = [module.agentless-scanning.scanning_role_component_id, module.agentless-scanning.crypto_key_component_id]
  depends_on = [module.agentless-scanning]
}
