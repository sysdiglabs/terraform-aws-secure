#---------------------------------------------------------------------------------------------
# Ensure installation flow for foundational onboarding has been completed before
# installing additional Sysdig features.
#---------------------------------------------------------------------------------------------
provider "aws" {
  alias  = "sns"
  region = "us-east-1"
}

module "cloud-logs" {
  source                   = "../../../modules/integrations/cloud-logs"
  bucket_arn               = "arn:aws:s3:::<your-cloudtrail-bucket-name>"
  bucket_account_id        = "<your-account-id>"
  kms_key_arn              = "arn:aws:kms:us-east-1:<your-account-id>:key/<your-kms-key-id>"
  regions                  = ["us-east-1"]
  topic_arn                = "arn:aws:sns:us-east-1:<your-account-id>:<your-topic-name>"
  create_topic             = false
  role_arn                 = "arn:aws:iam::<your-account-id>:role/<your-role-name>"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  is_organizational        = module.onboarding.is_organizational

  providers = {
    aws     = aws
    aws.sns = aws.sns
  }
}

output "kms_policy_instructions" {
  value = module.cloud-logs.kms_policy_instructions
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
  components = concat(
    sysdig_secure_cloud_auth_account_feature.identity_entitlement_basic.components,
    [module.cloud-logs.cloud_logs_component_id]
  )
  depends_on = [
    module.cloud-logs,
    sysdig_secure_cloud_auth_account_feature.identity_entitlement_basic
  ]
  flags = {
    "CIEM_FEATURE_MODE" = "advanced"
  }

  lifecycle {
    ignore_changes = [flags, components]
  }
}
