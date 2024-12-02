module "vm_workload_scanning" {
  source            	  = "sysdiglabs/secure/aws//modules/vm-workload-scanning"

  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
}


resource "sysdig_secure_cloud_auth_account_feature" "config_ecs" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS"
  enabled    = true
  components = [module.vm_workload_scanning.vm_workload_scanning_component_id]
  depends_on = [module.vm_workload_scanning]
}
