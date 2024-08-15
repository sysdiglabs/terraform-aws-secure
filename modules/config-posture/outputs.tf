output "config_posture_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.config_posture_role.type}/${sysdig_secure_cloud_auth_account_component.config_posture_role.instance}"
  description = "Component identifier of trusted identity created in Sysdig Backend for Config Posture"
  depends_on = [ sysdig_secure_cloud_auth_account_component.config_posture_role ]
}