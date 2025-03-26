#-----------------------------------------------------------------------------------------------------------------------
# This Terraform module creates the necessary resources to enable Sysdig's backend to fetch data from the
# CloudTrail-associated S3 bucket in the customer's AWS account. The setup includes:
#
# 1. When the bucket is in a different AWS account than where this module is deployed:
#    - Creates an IAM role in the bucket account via CloudFormation StackSet (for organizational deployments)
#      or via direct IAM role resource (for non-organizational deployments)
#    - The role allows Sysdig's trusted identity to assume it directly
#    - The role has permissions to access the S3 bucket and KMS keys (if applicable)
#
# 2. An AWS SNS Topic and Subscription for CloudTrail notifications, ensuring Sysdig's backend is notified whenever
#    new logs are published to the S3 bucket. The SNS Topic allows CloudTrail to publish notifications, while the
#    subscription forwards these notifications to Sysdig's ingestion service via HTTPS.
#
# 3. Support for KMS-encrypted S3 buckets:
#    - When KMS keys are in the same account as the bucket, the bucket-account role is granted decrypt permissions
#
# This setup assumes the customer has already configured an AWS CloudTrail Trail and its associated S3 bucket. The
# required details (e.g., bucket ARN, topic ARN, and regions) are either passed as module variables or derived from
# data sources.
#
# Note: Sysdig's Secure UI provides the necessary information to guide customers in setting up the required resources.
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {
  cloud_provider     = "aws"
  cloud_provider_id  = data.aws_caller_identity.current.account_id
}

#-----------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------
locals {
  account_id_hash  = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  role_name        = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
  bucket_role_name = "${local.role_name}-bucket"
  trusted_identity = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity

  topic_name = split(":", var.topic_arn)[5]
  routing_key      = data.sysdig_secure_cloud_ingestion_assets.assets.aws.sns_routing_key
  ingestion_url    = data.sysdig_secure_cloud_ingestion_assets.assets.aws.sns_routing_url
  
  # Determine bucket owner account ID - use provided value or default to current account
  bucket_account_id = var.bucket_account_id != null ? var.bucket_account_id : data.aws_caller_identity.current.account_id
  
  # Flag for cross-account bucket access
  is_cross_account = var.bucket_account_id != null && var.bucket_account_id != data.aws_caller_identity.current.account_id
  
  # Use stackset only for cross-account organizational deployments
  use_stackset = local.is_cross_account && var.is_organizational
  
  # Use direct IAM role for same-account or non-organizational cross-account deployments
  use_direct_role = !local.use_stackset 

  # StackSet configuration
  stackset_name = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}-stackset"
  bucket_name   = split(":", var.bucket_arn)[5]
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique role name suffix.
# This prevents conflicts when recreating a role with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

#-----------------------------------------------------------------------------------------------------------------------
# IAM Role for same-account access or non-organizational cross-account access
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "direct_s3_access" {
  count              = local.use_direct_role ? 1 : 0
  provider           = aws # Assumes provider is configured for bucket account in non-organizational scenario
  name               = local.bucket_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = local.trusted_identity
        },
        Condition = {
          StringEquals = {
            "sts:ExternalId" = data.sysdig_secure_tenant_external_id.external_id.external_id
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "direct_s3_access" {
  count  = local.use_direct_role ? 1 : 0
  name   = "s3_bucket_access"
  role   = aws_iam_role.direct_s3_access[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat([
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      }
    ], var.kms_key_arns != null ? [
      {
        Effect = "Allow",
        Action = "kms:Decrypt",
        Resource = var.kms_key_arns
      }
    ] : [])
  })
}

#-----------------------------------------------------------------------------------------------------------------------
# SNS Topic and Subscription for CloudTrail notifications
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_sns_topic" "cloudtrail_notifications" {
  count = var.create_topic ? 1 : 0
  name  = local.topic_name
  tags  = var.tags
}

resource "aws_sns_topic_policy" "cloudtrail_notifications" {
  count = var.create_topic ? 1 : 0
  arn   = aws_sns_topic.cloudtrail_notifications[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail_notifications[0].arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "cloudtrail_notifications" {
  topic_arn = var.topic_arn
  protocol  = "https"
  endpoint  = local.ingestion_url

  depends_on = [aws_sns_topic.cloudtrail_notifications]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the cloud logs integration
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_cloud_logs" {
  account_id       = var.sysdig_secure_account_id
  type             = "COMPONENT_CLOUD_LOGS"
  instance         = "secure-runtime"
  version          = "v1.0.0"
  cloud_logs_metadata = jsonencode({
    aws = {
      cloudtrailSns = {
        role_name        = local.bucket_role_name
        topic_arn        = var.topic_arn
        bucket_arn       = var.bucket_arn
        ingested_regions = var.regions
        routing_key      = local.routing_key
      }
    }
  })
}

#-----------------------------------------------------------------------------------------------------------------------
# Service-managed StackSet for creating the IAM role in the bucket account (for cross-account deployments)
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_cloudformation_stack_set" "bucket_permissions" {
  count = local.use_stackset ? 1 : 0

  name             = local.stackset_name
  description      = "StackSet to configure S3 bucket and KMS permissions for Sysdig Cloud Logs integration"
  template_body    = templatefile("${path.module}/stackset_template_body.tpl", {
    bucket_name      = local.bucket_name
    bucket_arn       = var.bucket_arn
    kms_key_arns     = var.kms_key_arns
    bucket_account_id = local.bucket_account_id
  })

  parameters = {
    TrustedIdentity = local.trusted_identity
    ExternalId = data.sysdig_secure_tenant_external_id.external_id.external_id
    BucketAccountId = local.bucket_account_id
    RoleName = local.bucket_role_name
  }

  permission_model       = "SERVICE_MANAGED"
  capabilities           = ["CAPABILITY_NAMED_IAM"]
  call_as                = "SELF"

  # Explicitly set auto_deployment to disabled
  auto_deployment {
    enabled = false
    retain_stacks_on_account_removal = false
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  tags = var.tags
}

resource "aws_cloudformation_stack_set_instance" "bucket_permissions" {
  count = local.use_stackset ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.bucket_permissions[0].name
  
  deployment_targets {
    organizational_unit_ids = var.org_units
  }
  
  region         = data.aws_region.current.name

  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    region_concurrency_type      = "SEQUENTIAL"
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}
