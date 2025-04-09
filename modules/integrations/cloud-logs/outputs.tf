output "cloud_logs_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.type}/${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.instance}"
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "kms_policy_instructions" {
  description = "Instructions for updating KMS key policy when KMS encryption is enabled"
  value = (local.need_kms_policy) ? templatefile(
    "${path.module}/templates/kms_policy_instructions.tpl",
    {
      role_arn = "arn:${data.aws_partition.current.partition}:iam::${local.bucket_account_id}:role/${local.role_name}"
    }
  ) : ""
}
