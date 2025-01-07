#-----------------------------------------------------------------------------------------------------------------------
# The only resource needed to make Sysdig's backend start to fetch data from the CloudTrail associated s3 bucket is a
# properly set AWS IAM Role. Sysdig's trusted identity act as the Principal in the assume role Policy, namely the role
# that the backend will use to assume the Client's role. At that point, given the permission set granted to the newly
# created Role in the Client's account, Sysdig's backend will be able to perform all the required actions in order to
# retrieve the log files that are automatically published in the target s3 bucket.
#
# Note: this setup assumes that the Customer has already properly set up an AWS CloudTrail Trail and the associated bucket.
# Sysdig's Secure UI provides the necessary information to make the Customer perform the
# required setup operations before applying the Terraform module.
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {
  cloud_provider = "aws"
  cloud_provider_id = data.aws_caller_identity.current.account_id
}

#-----------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------
locals {
  account_id_hash  = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  role_name = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
  bucket_arn = regex("^([^/]+)", var.folder_arn)[0]
  trusted_identity = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  topic_name = "${var.name}-cloudtrail-notifications-${random_id.suffix.hex}"
  create_topic = var.existing_topic_arn == ""
  topic_arn = local.create_topic ? aws_sns_topic.cloudtrail_notifications[0].arn : var.existing_topic_arn

  routing_key   = data.sysdig_secure_cloud_ingestion_assets.assets.sns_routing_key
  ingestion_url = data.sysdig_secure_cloud_ingestion_assets.assets.sns_metadata.ingestionURL
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique role name suffix.
# This prevents conflicts when recreating an role with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

# AWS IAM Role that will be used by CloudIngestion to access the CloudTrail-associated s3 bucket
resource "aws_iam_role" "cloudlogs_s3_access" {
  name = local.role_name
  tags = var.tags
  assume_role_policy = data.aws_iam_policy_document.assume_cloudlogs_s3_access_role.json
}

// AWS IAM Role Policy that will be used by CloudIngestion to access the CloudTrail-associated s3 bucket
resource "aws_iam_role_policy" "cloudlogs_s3_access_policy" {
  name   = "cloudlogs_s3_access_policy"
  role   = aws_iam_role.cloudlogs_s3_access.name
  policy = data.aws_iam_policy_document.cloudlogs_s3_access.json
}

# IAM Policy Document used for the assume role policy
data "aws_iam_policy_document" "assume_cloudlogs_s3_access_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.trusted_identity]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.sysdig_secure_tenant_external_id.external_id.external_id]
    }
  }
}

# IAM Policy Document used for the bucket access policy
data "aws_iam_policy_document" "cloudlogs_s3_access" {
  statement {
    sid = "CloudlogsS3AccessGet"

    effect = "Allow"

    actions = [
      "s3:Get*",
    ]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*"
    ]
  }
}

#-----------------------------------------------------------------------------------------------------------------------
# SNS Topic and Subscription for CloudTrail notifications
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_sns_topic" "cloudtrail_notifications" {
  count = local.create_topic ? 1 : 0
  name = local.topic_name
  tags = var.tags
}

resource "aws_sns_topic_policy" "cloudtrail_notifications" {
  count = local.create_topic ? 1 : 0
  arn = aws_sns_topic.cloudtrail_notifications[0].arn
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
  topic_arn = local.topic_arn
  protocol  = "https"
  endpoint  = local.ingestion_url
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the cloud logs integration
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_cloud_logs" {
  account_id = var.sysdig_secure_account_id
  type       = "COMPONENT_CLOUD_LOGS"
  instance   = "secure-runtime"
  version    = "v1.0.0"
  cloud_logs_metadata = jsonencode({
    aws = {
      cloudtrailSns = {
        role_name        = local.role_name
        topic_arn        = local.topic_arn
        subscription_arn = aws_sns_topic_subscription.cloudtrail_notifications.arn
        bucket_region    = var.bucket_region
        bucket_arn       = local.bucket_arn
        ingested_regions = var.regions
        routing_key      = local.routing_key
      }
    }
  })
}
