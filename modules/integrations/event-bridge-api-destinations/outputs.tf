output "event_bridge_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_event_bridge_api_dest.type}/${sysdig_secure_cloud_auth_account_component.aws_event_bridge_api_dest.instance}"
  description = "Component identifier of Event Bridge integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_event_bridge_api_dest]
}
