output "cloud_logs_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.type}/${sysdig_secure_cloud_auth_account_component.aws_cloud_logs.instance}"
  description = "Component identifier of Cloud Logs integration created in Sysdig Backend for Log Ingestion"
  depends_on = [ sysdig_secure_cloud_auth_account_component.aws_cloud_logs ]
}

output "extra_permissions_s3_bucket" {
  value       = ( var.is_s3_bucket_in_different_account
    ? <<-EOT

      Please add following extra permissions to cloudtrail S3 bucket:

              {
                "Sid": "Sysdig-Get",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "${aws_iam_role.cloudlogs_s3_access.arn}"
                },
                "Action": "s3:GetObject",
                "Resource": "${var.bucket_arn}/*"
              }
      EOT
    : null )
  description = "Extra permissions to add to s3 bucket"
  depends_on = [ sysdig_secure_cloud_auth_account_component.aws_cloud_logs ]
}

output "extra_permissions_kms_key" {
  value       = ( var.is_log_file_kms_encryption_enabled
    ? <<-EOT

      Please add following extra permissions to KMS key policy:

              {
                "Sid": "Sysdig-Decrypt",
                "Effect": "Allow",
                "Principal": {
                  "AWS": "${aws_iam_role.cloudlogs_s3_access.arn}"
                },
                "Action": "kms:Decrypt",
                "Resource": "*",
                "Condition": {
                  "StringEquals": {
                    "kms:ViaService": "s3.${regex("^arn:aws:kms:([^:]+):\\d+:key/.*$", var.kms_key_arn)[0]}.amazonaws.com"
                  },
                  "StringLike": {
                    "kms:EncryptionContext:aws:s3:arn": "${var.bucket_arn}/*"
                  }
                }
              }
      EOT
    : null )
  description = "Extra permissions to add to KMS key policy"
  depends_on = [ sysdig_secure_cloud_auth_account_component.aws_cloud_logs ]
}