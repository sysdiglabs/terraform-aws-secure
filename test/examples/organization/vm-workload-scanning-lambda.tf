module "vm_workload_scanning" {
  source            	     = "sysdiglabs/secure/aws//modules/vm-workload-scanning"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = module.onboarding.is_organizational
  # legacy org install
  # organizational_unit_ids = module.onboarding.organizational_unit_ids

  # include/exclude org install params
  include_ouids = module.onboarding.include_ouids
  exclude_ouids = module.onboarding.exclude_ouids
  include_accounts = module.onboarding.include_accounts
  exclude_accounts = module.onboarding.exclude_accounts

  lambda_scanning_enabled = true
}


resource "sysdig_secure_cloud_auth_account_feature" "config_lambda" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS"
  enabled    = true
  components = [module.vm_workload_scanning.vm_workload_scanning_component_id]
  depends_on = [module.vm_workload_scanning]
}
