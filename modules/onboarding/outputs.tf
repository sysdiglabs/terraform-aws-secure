output "account_id" {
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
