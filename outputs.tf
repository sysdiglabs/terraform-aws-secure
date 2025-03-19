output "cloud_logs_role_arn" {
  description = "ARN of the IAM role created for accessing CloudTrail logs."
  value       = module.cloud-logs.cloudlogs_role_arn
}

output "extra_permissions_s3_bucket" {
  description = "Extra permissions to add to the S3 bucket policy for cross-account access"
  value       = module.cloud-logs.extra_permissions_s3_bucket
}

output "extra_permissions_kms_key" {
  description = "Extra permissions to add to the KMS key policy for cross-account access"
  value       = module.cloud-logs.extra_permissions_kms_key
} 