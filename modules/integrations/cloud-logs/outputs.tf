output "cloud_logs_component_id" {
  value       = sysdig_secure_cloud_auth_account_component.aws_cloud_logs.id
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "kms_policy_instructions" {
  description = "Instructions for updating KMS key policy when KMS encryption is enabled"
  value = (var.kms_key_arn != null) ? templatefile(
    "${path.module}/templates/kms_policy_instructions.tpl",
    {
      role_arn = "arn:${data.aws_partition.current.partition}:iam::${local.bucket_account_id}:role/${local.role_name}"
      region = data.aws_region.current.name
      bucket_name = local.bucket_name
    }
  ) : ""
}
