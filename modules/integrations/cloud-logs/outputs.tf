output "cloud_logs_component_id" {
  value       = sysdig_secure_cloud_auth_account_component.aws_cloud_logs.id
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "cloudlogs_role_arn" {
  value       = local.use_direct_role ? aws_iam_role.direct_s3_access[0].arn : null
  description = "ARN of the IAM role created for accessing CloudTrail logs (only for non-organizational deployments)"
}
