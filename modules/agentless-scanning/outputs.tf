output "scanning_role_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_scanning_role.type}/${sysdig_secure_cloud_auth_account_component.aws_scanning_role.instance}"
  description = "Component identifier of scanning role created in Sysdig Backend for Agentless Scanning"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_scanning_role]
}

output "crypto_key_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_crypto_key.type}/${sysdig_secure_cloud_auth_account_component.aws_crypto_key.instance}"
  description = "Component identifier of KMS crypto key created in Sysdig Backend for Agentless Scanning"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_crypto_key]
}