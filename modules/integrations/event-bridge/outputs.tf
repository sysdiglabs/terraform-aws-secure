output "event_bridge_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_event_bridge.type}/${sysdig_secure_cloud_auth_account_component.aws_event_bridge.instance}"
  description = "Component identifier of Event Bridge integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_event_bridge]
}

output "post_ciem_basic_delay" {
  value       = var.wait_after_basic_seconds > 0 ? time_sleep.wait_after_ciem_basic : null
  description = "Wait handle to delay downstream operations after basic (e.g., CIEM) by the configured seconds."
}
