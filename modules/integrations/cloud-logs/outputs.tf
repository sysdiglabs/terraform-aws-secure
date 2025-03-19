output "cloud_logs_component_id" {
  value       = sysdig_secure_cloud_auth_account_component.aws_cloud_logs.id
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "cloudlogs_role_arn" {
  value       = aws_iam_role.cloudlogs_s3_access.arn
  description = "ARN of the IAM role created for accessing CloudTrail logs. Use this ARN in the bucket policy when configuring cross-account access."
}

output "cross_account_setup_instructions" {
  description = "Instructions for completing the cross-account setup in the bucket owner account."
  
  value = var.bucket_account_id != null && var.bucket_account_id != data.aws_caller_identity.current.account_id ? "IMPORTANT: CROSS-ACCOUNT CONFIGURATION REQUIRED\n\nYou have configured cross-account access for CloudTrail logs.\nTo complete the setup, the following changes MUST be made in the bucket owner account (${var.bucket_account_id}):\n\n1. Add this statement to the S3 bucket policy:\n\n{\n  \"Effect\": \"Allow\",\n  \"Principal\": {\n    \"AWS\": \"${aws_iam_role.cloudlogs_s3_access.arn}\"\n  },\n  \"Action\": [\n    \"s3:GetObject\",\n    \"s3:ListBucket\"\n  ],\n  \"Resource\": [\n    \"${var.bucket_arn}\",\n    \"${var.bucket_arn}/*\"\n  ]\n}\n\n2. If the bucket is encrypted with KMS, also add this statement to the KMS key policy:\n\n{\n  \"Effect\": \"Allow\",\n  \"Principal\": {\n    \"AWS\": \"${aws_iam_role.cloudlogs_s3_access.arn}\"\n  },\n  \"Action\": [\n    \"kms:Decrypt\"\n  ],\n  \"Resource\": \"*\"\n}\n\nWithout these changes, the CloudTrail logs cannot be accessed and you will see \"Access Denied\" errors." : "No cross-account setup required because you're using the same account for both trail and bucket."
}
