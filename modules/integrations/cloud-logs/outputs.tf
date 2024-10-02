output "cloud_logs_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.type}/${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.instance}"
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on = [ sysdig_secure_cloud_auth_account_component.aws_cloud_logs ]
}
