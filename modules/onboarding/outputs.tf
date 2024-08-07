output "account_id" {
  value       = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  description = "sysdig secure cloud account identifier"
}

output "organizational" {
  value       = var.organizational
  description = "onboard the organization in which account resides"
}
