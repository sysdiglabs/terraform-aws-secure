output "config_posture_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.config_posture_role.type}/${sysdig_secure_cloud_auth_account_component.config_posture_role.instance}"
  description = "Component identifier of trusted identity created in Sysdig Backend for Config Posture"
  depends_on  = [sysdig_secure_cloud_auth_account_component.config_posture_role]
}

output "cspm_role_arn" {
  value       = aws_iam_role.cspm_role.arn
  description = "The ARN of the CSPM role"
  depends_on  = [aws_iam_role.cspm_role]
}

output "sysdig_secure_account_id" {
  value       = var.sysdig_secure_account_id
  description = "ID of the Sysdig Cloud Account to enable Config Posture for (incase of organization, ID of the Sysdig management account)"
}
