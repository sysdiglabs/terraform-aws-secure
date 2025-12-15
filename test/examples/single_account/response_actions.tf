module "response-actions" {
  source                   = "../../../modules/response-actions"
  regions                  = ["us-east-1","us-east-2","us-west-1","us-west-2","ap-northeast-1","ca-central-1","eu-central-1","eu-west-1","eu-west-2","eu-west-3","eu-south-1","eu-north-1","sa-east-1"]
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id

  api_base_url             = "https://secure-staging2-new.sysdigcloud.com"
  enabled_response_actions = ["make_private", "fetch_cloud_logs", "create_volume_snapshot", "quarantine_user"]
}

resource "sysdig_secure_cloud_auth_account_feature" "response_actions" {
  account_id = module.onboarding.sysdig_secure_account_id
  type       = "FEATURE_SECURE_RESPONSE_ACTIONS"
  enabled    = true
  components = [module.response-actions.responder_component_id, module.response-actions.responder_roles_component_id]
  depends_on = [module.response-actions, module.response-actions.wait_after_basic]
}