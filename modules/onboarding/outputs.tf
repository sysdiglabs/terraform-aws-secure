output "sysdig_secure_account_id" {
  value       = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  description = "sysdig secure cloud account identifier"
}

output "is_organizational" {
  value       = var.is_organizational
  description = "onboard the organization in which account resides"
}

output "organizational_unit_ids" {
  value       = var.organizational_unit_ids
  description = "organizational unit ids to onboard"
}

output "is_gov_cloud_onboarding" {
  value       = var.is_gov_cloud_onboarding
  description = "onboard the govcloud account/organization"
}

output "include_ouids" {
  description = "ouids to include for organization"
  value = var.include_ouids
}

output "exclude_ouids" {
  description = "ouids to exclude for organization"
  value = var.exclude_ouids
}

output "include_accounts" {
  description = "accounts to include for organization"
  value = var.include_accounts
}

output "exclude_accounts" {
  description = "accounts to exclude for organization"
  value = var.exclude_accounts
}