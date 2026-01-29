module "vm_workload_scanning" {
  source                   = "../../../modules/vm-workload-scanning"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = module.onboarding.is_organizational

  # include/exclude org install params
  include_ouids    = module.onboarding.include_ouids
  exclude_ouids    = module.onboarding.exclude_ouids
  include_accounts = module.onboarding.include_accounts
  exclude_accounts = module.onboarding.exclude_accounts
}


resource "sysdig_secure_cloud_auth_account_feature" "config_ecs" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS"
  enabled    = true
  components = [module.vm_workload_scanning.vm_workload_scanning_component_id]
  depends_on = [module.vm_workload_scanning]
}
