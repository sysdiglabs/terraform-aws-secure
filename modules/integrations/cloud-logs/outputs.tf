output "cloud_logs_component_id" {
  value       = sysdig_secure_cloud_auth_account_component.aws_cloud_logs.id
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "cloudlogs_role_arn" {
  value       = aws_iam_role.cloudlogs_s3_access.arn
  description = "ARN of the IAM role created for accessing CloudTrail logs. Use this ARN in the bucket policy when configuring cross-account access."
}

output "extra_permissions_s3_bucket" {
  value = (var.bucket_account_id != null && var.bucket_account_id != data.aws_caller_identity.current.account_id
    ? <<-EOT
      ╔═══════════════════════════════════════════════════════════════════════════════╗
      ║  IMPORTANT: CROSS-ACCOUNT S3 BUCKET CONFIGURATION REQUIRED                    ║
      ╚═══════════════════════════════════════════════════════════════════════════════╝
      
      CloudTrail logs are stored in account ${var.bucket_account_id}, but Sysdig is deployed in a different account.
      You MUST add the following permission statement to the S3 bucket policy in account ${var.bucket_account_id}:
      
      {
        "Sid": "SysdigCloudTrailAccess",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${aws_iam_role.cloudlogs_s3_access.arn}"
        },
        "Action": [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "${var.bucket_arn}",
          "${var.bucket_arn}/*"
        ]
      }
      
      Without this change, the CloudTrail logs cannot be accessed and you will see "Access Denied" errors.
    EOT
    : null)
  description = "Extra permissions to add to the S3 bucket policy for cross-account access"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}

output "extra_permissions_kms_key" {
  value = (var.bucket_account_id != null && var.bucket_account_id != data.aws_caller_identity.current.account_id && var.kms_key_arns != null
    ? <<-EOT
      ╔═══════════════════════════════════════════════════════════════════════════════╗
      ║  IMPORTANT: CROSS-ACCOUNT KMS KEY CONFIGURATION REQUIRED                      ║
      ╚═══════════════════════════════════════════════════════════════════════════════╝
      
      CloudTrail logs are encrypted with KMS in account ${var.bucket_account_id}, but Sysdig is deployed in a different account.
      You MUST add the following permission statement to the KMS key policy in account ${var.bucket_account_id}:
      
      {
        "Sid": "SysdigKMSDecrypt",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${aws_iam_role.cloudlogs_s3_access.arn}"
        },
        "Action": "kms:Decrypt",
        "Resource": "*"
      }
      
      Without this change, the encrypted CloudTrail logs cannot be decrypted and you will see "Access Denied" errors.
    EOT
    : null)
  description = "Extra permissions to add to the KMS key policy for cross-account access"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_cloud_logs]
}
