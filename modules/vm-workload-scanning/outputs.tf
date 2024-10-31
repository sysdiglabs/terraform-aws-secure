output "role_arn" {
  description = "Role used by Sysdig Platform for Agentless Workload Scanning"
  value       = var.is_organizational ? null : aws_iam_role.scanning[0].arn
}

output "vm_workload_scanning_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.vm_workload_scanning_account_component.type}/${sysdig_secure_cloud_auth_account_component.vm_workload_scanning_account_component.instance}"
  description = "Component identifier of trusted identity created in Sysdig Backend for VM Workload Scanning"
  depends_on  = [sysdig_secure_cloud_auth_account_component.vm_workload_scanning_account_component]
}
