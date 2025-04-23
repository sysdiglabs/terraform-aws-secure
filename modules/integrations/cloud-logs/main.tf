#-----------------------------------------------------------------------------------------------------------------------
# This Terraform module creates the necessary resources to enable Sysdig's backend to fetch data from the
# CloudTrail-associated S3 bucket in the customer's AWS account. The setup includes:
#
# 1. For single-account deployments:
#    - An AWS IAM Role in the account with permissions to access the S3 bucket directly
#
# 2. For organizational deployments (same account):
#    - An AWS IAM Role in the management account with permissions to access the S3 bucket directly
#
# 3. For organizational cross-account deployments:
#    - A CloudFormation StackSet deploys an IAM role directly in the bucket account
#    - The role in the bucket account allows Sysdig to access S3 data directly
#
# Common resources for all scenarios:
# - An AWS SNS Topic and Subscription for CloudTrail notifications, ensuring Sysdig's backend is notified whenever
#   new logs are published to the S3 bucket
# - Support for KMS-encrypted S3 buckets, with roles granted proper decrypt permissions
#
# This setup assumes the customer has already configured an AWS CloudTrail Trail and its associated S3 bucket.
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {
  cloud_provider     = "aws"
  cloud_provider_id  = data.aws_caller_identity.current.account_id
}

#----------------------------------------------------------
# Fetch & compute required data for organizational install
#----------------------------------------------------------
data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}


#-----------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------
locals {
  trusted_identity = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity


  routing_key      = data.sysdig_secure_cloud_ingestion_assets.assets.aws.sns_routing_key
  ingestion_url    = data.sysdig_secure_cloud_ingestion_assets.assets.aws.sns_routing_url

  # Topic variables
  topic_name = split(":", var.topic_arn)[5]
  topic_region = split(":", var.topic_arn)[3]
  topic_account_id = split(":", var.topic_arn)[4]
  is_cross_account_topic = local.topic_account_id != data.aws_caller_identity.current.account_id

  # Bucket variables
  bucket_account_id = var.bucket_account_id != null ? var.bucket_account_id : data.aws_caller_identity.current.account_id
  is_cross_account = var.bucket_account_id != null && var.bucket_account_id != data.aws_caller_identity.current.account_id

  # KMS variables
  kms_account_id = split(":", var.kms_key_arn)[3]
  need_kms_policy = var.bucket_account_id != null && var.bucket_account_id != local.kms_account_id

  # Role variables
  role_name = split("/", var.role_arn)[1]

  account_id_hash  = substr(md5(local.bucket_account_id), 0, 4)
  # StackSet configuration
  stackset_name = "sysdig-secure-cloudlogs-${random_id.suffix.hex}-${local.account_id_hash}-stackset"

  # fetch the AWS Root OU under org
  # As per https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html#organization-structure, there can be only one root
  root_org_unit = var.is_organizational ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : []
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique role name suffix.
# This prevents conflicts when recreating an role with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

# AWS IAM Role in the management account
# Created for all scenarios EXCEPT organizational cross-account deployments
resource "aws_iam_role" "cloudlogs_s3_access" {
  count              = local.is_cross_account ? 0 : 1
  name               = local.role_name
  tags               = var.tags
  assume_role_policy = data.aws_iam_policy_document.assume_cloudlogs_s3_access_role.json
}

// AWS IAM Role Policy
resource "aws_iam_role_policy" "cloudlogs_s3_access_policy" {
  count  = local.is_cross_account ? 0 : 1
  name   = "cloudlogs_s3_access_policy"
  role   = aws_iam_role.cloudlogs_s3_access[0].name
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
  # For same account bucket access
  dynamic "statement" {
    for_each = !local.is_cross_account ? [1] : []
    content {
      sid = "CloudlogsS3Access"

      effect = "Allow"

      actions = [
        "s3:Get*",
        "s3:List*"
      ]

      resources = [
        var.bucket_arn,
        "${var.bucket_arn}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid = "CloudlogsKMSDecrypt"
      
      effect = "Allow"
      
      actions = [
        "kms:Decrypt"
      ]
      
      resources = [var.kms_key_arn]
    }
  }
}

#-----------------------------------------------------------------------------------------------------------------------
# SNS Topic and Subscription for CloudTrail notifications
#-----------------------------------------------------------------------------------------------------------------------
provider aws {
  alias = "sns"
  region = local.topic_region
}

resource "aws_sns_topic" "cloudtrail_notifications" {
  count = var.create_topic ? 1 : 0
  provider = aws.sns
  name  = local.topic_name
  tags  = var.tags
}

resource "aws_sns_topic_policy" "cloudtrail_notifications" {
  count = var.create_topic ? 1 : 0
  provider = aws.sns
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
  count = !local.is_cross_account_topic ? 1 : 0
  topic_arn = var.topic_arn
  provider = aws.sns
  protocol  = "https"
  endpoint  = local.ingestion_url

  depends_on = [aws_sns_topic.cloudtrail_notifications]
}

#-----------------------------------------------------------------------------------------------------------------------
# Service-managed StackSet for creating a role in the bucket account for organizational deployments
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_cloudformation_stack_set" "cloudlogs_s3_access" {
  count = local.is_cross_account ? 1 : 0

  name             = local.stackset_name
  description      = "StackSet to configure S3 bucket and KMS permissions for Sysdig Cloud Logs integration"
  template_body    = templatefile("${path.module}/templates/stackset_template_body.tpl", {
    bucket_arn = var.bucket_arn
    kms_key_arn = var.kms_key_arn
  })

  parameters = {
    RoleName = local.role_name
    BucketAccountId = local.bucket_account_id
    TopicAccountId = local.topic_account_id
    SysdigTrustedIdentity = local.trusted_identity
    SysdigExternalId = data.sysdig_secure_tenant_external_id.external_id.external_id
    KmsKeyArn = var.kms_key_arn
    TopicArn = var.topic_arn
    IngestionUrl = local.ingestion_url
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

# StackSet instance for the bucket account
resource "aws_cloudformation_stack_set_instance" "cloudlogs_s3_access_bucket" {
  count = local.is_cross_account ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.cloudlogs_s3_access[0].name
  
  deployment_targets {
    organizational_unit_ids = local.root_org_unit
    account_filter_type = "INTERSECTION"
    accounts = [local.bucket_account_id]
  }
  
  region = data.aws_region.current.name

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}

# StackSet instance for the topic account
resource "aws_cloudformation_stack_set_instance" "cloudlogs_s3_access_topic" {
  count = local.is_cross_account ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.cloudlogs_s3_access[0].name
  
  deployment_targets {
    organizational_unit_ids = local.root_org_unit
    account_filter_type = "INTERSECTION"
    accounts = [local.topic_account_id]
  }
  
  region = local.topic_region

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the cloud logs integration
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_cloud_logs" {
  account_id       = var.sysdig_secure_account_id
  type             = "COMPONENT_CLOUD_LOGS"
  instance         = "secure-runtime"
  version          = "v1.0.1"
  cloud_logs_metadata = jsonencode({
    aws = {
      cloudtrailSns = {
        role_name        = local.role_name
        topic_arn        = var.topic_arn
        bucket_arn       = var.bucket_arn
        ingested_regions = var.regions
        routing_key      = local.routing_key
        role_account_id  = local.bucket_account_id
      }
    }
  })

  depends_on = [
    aws_iam_role.cloudlogs_s3_access,
    aws_cloudformation_stack_set_instance.cloudlogs_s3_access_bucket,
    aws_cloudformation_stack_set_instance.cloudlogs_s3_access_topic
  ]
}
