#-----------------------------------------------------------------------------------------------------------------------------------------
# This module deploys Sysdig Secure Response Actions for AWS, enabling automated security responses to detected threats.
#
# For both Single Account and Organizational installs, Lambda functions are deployed using CloudFormation StackSets.
# For Organizational installs, see organizational.tf.
#
# Response Actions include:
# - Quarantine User: Attaches a deny-all policy to IAM users to prevent further actions
# - Fetch Cloud Logs: Retrieves CloudTrail and CloudWatch logs
# - Make Private: Removes public access from S3 buckets and RDS instances
# - Create Volume Snapshot: Creates EBS volume snapshots for forensic investigation
#
# For single installs, the resources in this file instrument the singleton account (management or member account).
# For organizational installs, resources in this file are created in the management account, with delegate roles
# deployed to member accounts via service-managed stacksets.
#-----------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Use provided regions or default to current region
  region_set               = length(var.regions) > 0 ? toset(var.regions) : toset([data.aws_region.current.id])
  trusted_identity         = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix               = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
  responder_component_type = "COMPONENT_CLOUD_RESPONDER"
  roles_component_type     = "COMPONENT_CLOUD_RESPONDER_ROLES"
  account_id_hash          = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  ra_resource_name         = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"

  # Centralized role names
  quarantine_user_role_name           = "${local.ra_resource_name}-quarantine-user-role"
  fetch_cloud_logs_role_name          = "${local.ra_resource_name}-fetch-cloud-logs-role"
  remove_policy_role_name             = "${local.ra_resource_name}-remove-policy-role"
  configure_resource_access_role_name = "${local.ra_resource_name}-confi-res-access-role"
  create_volume_snapshots_role_name   = "${local.ra_resource_name}-create-vol-snap-role"
  delete_volume_snapshots_role_name   = "${local.ra_resource_name}-delete-vol-snap-role"

  # Centralized Lambda function names
  quarantine_user_lambda_name           = "${local.ra_resource_name}-quarantine-user"
  fetch_cloud_logs_lambda_name          = "${local.ra_resource_name}-fetch-cloud-logs"
  remove_policy_lambda_name             = "${local.ra_resource_name}-remove-policy"
  configure_resource_access_lambda_name = "${local.ra_resource_name}-configure-resource-access"
  create_volume_snapshots_lambda_name   = "${local.ra_resource_name}-create-volume-snapshots"
  delete_volume_snapshots_lambda_name   = "${local.ra_resource_name}-delete-volume-snapshots"

  # Policy templates with role names
  quarantine_user_policy           = templatefile("${path.module}/policies/quarantine-user-policy.json", { role_name = local.quarantine_user_role_name })
  fetch_cloud_logs_policy          = templatefile("${path.module}/policies/fetch-cloud-logs-policy.json", { role_name = local.fetch_cloud_logs_role_name })
  remove_policy_policy             = templatefile("${path.module}/policies/remove-policy-policy.json", { role_name = local.remove_policy_role_name })
  configure_resource_access_policy = templatefile("${path.module}/policies/configure-resource-access-policy.json", { role_name = local.configure_resource_access_role_name })
  create_volume_snapshots_policy   = templatefile("${path.module}/policies/create-volume-snapshots-policy.json", { role_name = local.create_volume_snapshots_role_name })
  delete_volume_snapshots_policy   = templatefile("${path.module}/policies/delete-volume-snapshots-policy.json", { role_name = local.delete_volume_snapshots_role_name })

  # StackSet role configuration
  administration_role_arn = var.auto_create_stackset_roles ? aws_iam_role.lambda_stackset_admin_role[0].arn : var.stackset_admin_role_arn
  execution_role_name     = var.auto_create_stackset_roles ? aws_iam_role.lambda_stackset_execution_role[0].name : var.stackset_execution_role_name

  # S3 bucket configuration for Lambda packages
  s3_bucket_name = "${local.ra_resource_name}-packages"

  # Response action enablement flags
  enable_make_private           = contains(var.enabled_response_actions, "make_private")
  enable_fetch_cloud_logs       = contains(var.enabled_response_actions, "fetch_cloud_logs")
  enable_create_volume_snapshot = contains(var.enabled_response_actions, "create_volume_snapshot")
  enable_quarantine_user        = contains(var.enabled_response_actions, "quarantine_user")

  # Build list of Lambda ARNs for invoke policy based on enabled actions
  enabled_lambda_arns = concat(
    local.enable_quarantine_user ? [
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.quarantine_user_lambda_name}",
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.remove_policy_lambda_name}"
    ] : [],
    local.enable_fetch_cloud_logs ? [
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.fetch_cloud_logs_lambda_name}"
    ] : [],
    local.enable_make_private ? [
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.configure_resource_access_lambda_name}"
    ] : [],
    local.enable_create_volume_snapshot ? [
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.create_volume_snapshots_lambda_name}",
      "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.delete_volume_snapshots_lambda_name}"
    ] : []
  )

  # Build list of Lambda function names based on enabled actions
  enabled_lambda_names = concat(
    local.enable_quarantine_user ? [
      local.quarantine_user_lambda_name,
      local.remove_policy_lambda_name
    ] : [],
    local.enable_fetch_cloud_logs ? [
      local.fetch_cloud_logs_lambda_name
    ] : [],
    local.enable_make_private ? [
      local.configure_resource_access_lambda_name
    ] : [],
    local.enable_create_volume_snapshot ? [
      local.create_volume_snapshots_lambda_name,
      local.delete_volume_snapshots_lambda_name
    ] : []
  )

  wait_duration = format("%ds", var.wait_after_basic_seconds)
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique resource name suffix for Response Actions.
# This prevents conflicts when recreating Response Actions resources with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require a pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets. If false, and values for stackset Admin role ARN is provided, stackset will use it, else AWS will look for
# predefined/default role.
#-----------------------------------------------------------------------------------------------------------------------------------------
# StackSet Administration Role
resource "aws_iam_role" "lambda_stackset_admin_role" {
  count = var.auto_create_stackset_roles ? 1 : 0
  name  = "${local.ra_resource_name}-stackset-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = "${local.ra_resource_name}-stackset-admin"
    "sysdig.com/response-actions/resource-name" = "stackset-admin"
  }
}

resource "aws_iam_role_policy" "lambda_stackset_admin_policy" {
  count = var.auto_create_stackset_roles ? 1 : 0
  name  = "${local.ra_resource_name}-stackset-admin-policy"
  role  = aws_iam_role.lambda_stackset_admin_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "${local.arn_prefix}:iam::*:role/${local.ra_resource_name}-stackset-execution"
      }
    ]
  })
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require a pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Execution role in the source account with permissions to
# deploy Lambda functions, create IAM roles, and manage logs. This role is assumed by the StackSet Administration role.
# If false, and values for stackset Execution role name is provided, stackset will use it.
#-----------------------------------------------------------------------------------------------------------------------------------------
# StackSet Execution Role
resource "aws_iam_role" "lambda_stackset_execution_role" {
  count = var.auto_create_stackset_roles ? 1 : 0
  name  = "${local.ra_resource_name}-stackset-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.auto_create_stackset_roles ? aws_iam_role.lambda_stackset_admin_role[0].arn : var.stackset_admin_role_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = "${local.ra_resource_name}-stackset-execution"
    "sysdig.com/response-actions/resource-name" = "stackset-execution"
  }
}

resource "aws_iam_role_policy" "lambda_stackset_execution_policy" {
  count = var.auto_create_stackset_roles ? 1 : 0
  name  = "${local.ra_resource_name}-stackset-execution-policy"
  role  = aws_iam_role.lambda_stackset_execution_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:TagLogGroup",
          "logs:ListTagsForResource",
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_stackset_execution_cloudformation" {
  count      = var.auto_create_stackset_roles ? 1 : 0
  role       = aws_iam_role.lambda_stackset_execution_role[0].name
  policy_arn = "${local.arn_prefix}:iam::aws:policy/AWSCloudFormationFullAccess"
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#-----------------------------------------------------------------------------------------------------------------------------------------
# This resource creates an IAM role in the source account with permissions to invoke Response Action Lambda functions.
# This role is assumed by Sysdig's cloud identity to trigger automated response actions.
#
# The role allows:
# 1. Sysdig's trusted identity to assume the role using an external ID for security
# 2. Invoking Lambda functions across all deployed regions based on enabled response actions
# 3. Using AWS Resource Groups Tagging API to discover resources
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "shared_cross_account_lambda_invoker" {
  name = "${local.ra_resource_name}-cross-account-invoker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = local.trusted_identity
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "cloud-actions-lambda-invoke-access"
          }
        }
      }
    ]
  })

  tags = {
    Name                                        = "${local.ra_resource_name}-cross-account-invoker"
    "sysdig.com/response-actions/resource-name" = "cross-account-invoker"
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# This policy grants the necessary permissions for the cross-account Lambda invoker role:
# 1. tag:GetResources - Allows discovering AWS resources by tags for response actions
# 2. lambda:InvokeFunction - Allows invoking enabled Response Action Lambda functions
# 3. lambda:GetFunction - Allows retrieving Lambda function details for validation
#
# The policy dynamically includes only the Lambda ARNs for enabled response actions, based on the
# enabled_response_actions variable configuration.
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "shared_lambda_invoke_policy" {
  name = "${local.ra_resource_name}-invoke-policy"
  role = aws_iam_role.shared_cross_account_lambda_invoker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
      ],
      length(local.enabled_lambda_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction"
        ]
        Resource = local.enabled_lambda_arns
      }] : []
    )
  })
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# IAM Roles for Lambda Functions (Created Once in Management Account)
#
# These roles are created globally in the management account and are used by Lambda functions
# across all regions. Each role is tagged with 'sysdig.com/response-actions/cloud-actions = true' for identification.
#
# The roles grant specific permissions needed for each response action type:
# - Quarantine User: IAM policy and user management permissions
# - Fetch Cloud Logs: CloudTrail and CloudWatch Logs read access
# - Remove Policy: IAM policy detachment permissions
# - Configure Resource Access: S3 and EC2 security group modification permissions
# - Create/Delete Volume Snapshots: EBS snapshot management permissions
#-----------------------------------------------------------------------------------------------------------------------------------------

# Lambda Execution Role: Quarantine User
resource "aws_iam_role" "quarantine_user_role" {
  count = local.enable_quarantine_user ? 1 : 0
  name  = local.quarantine_user_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.quarantine_user_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "quarantine-user-role"
  }
}

resource "aws_iam_role_policy_attachment" "quarantine_user_basic" {
  count      = local.enable_quarantine_user ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.quarantine_user_role[0].name
}

resource "aws_iam_role_policy" "quarantine_user_policy" {
  count  = local.enable_quarantine_user ? 1 : 0
  name   = "${local.ra_resource_name}-quarantine-user-policy"
  role   = aws_iam_role.quarantine_user_role[0].id
  policy = local.quarantine_user_policy
}

# Lambda Execution Role: Fetch Cloud Logs
resource "aws_iam_role" "fetch_cloud_logs_role" {
  count = local.enable_fetch_cloud_logs ? 1 : 0
  name  = local.fetch_cloud_logs_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.fetch_cloud_logs_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "fetch-cloud-logs-role"
  }
}

resource "aws_iam_role_policy_attachment" "fetch_cloud_logs_basic" {
  count      = local.enable_fetch_cloud_logs ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.fetch_cloud_logs_role[0].name
}

resource "aws_iam_role_policy" "fetch_cloud_logs_policy" {
  count  = local.enable_fetch_cloud_logs ? 1 : 0
  name   = "${local.ra_resource_name}-fetch-cloud-logs-policy"
  role   = aws_iam_role.fetch_cloud_logs_role[0].id
  policy = local.fetch_cloud_logs_policy
}

# Lambda Execution Role: Remove Policy
resource "aws_iam_role" "remove_policy_role" {
  count = local.enable_quarantine_user ? 1 : 0
  name  = local.remove_policy_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.remove_policy_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "remove-policy-role"
  }
}

resource "aws_iam_role_policy_attachment" "remove_policy_basic" {
  count      = local.enable_quarantine_user ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.remove_policy_role[0].name
}

resource "aws_iam_role_policy" "remove_policy_policy" {
  count  = local.enable_quarantine_user ? 1 : 0
  name   = "${local.ra_resource_name}-remove-policy-policy"
  role   = aws_iam_role.remove_policy_role[0].id
  policy = local.remove_policy_policy
}

# Lambda Execution Role: Configure Resource Access
resource "aws_iam_role" "configure_resource_access_role" {
  count = local.enable_make_private ? 1 : 0
  name  = local.configure_resource_access_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.configure_resource_access_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "configure-resource-access-role"
  }
}

resource "aws_iam_role_policy_attachment" "configure_resource_access_basic" {
  count      = local.enable_make_private ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.configure_resource_access_role[0].name
}

resource "aws_iam_role_policy" "configure_resource_access_policy" {
  count  = local.enable_make_private ? 1 : 0
  name   = "${local.ra_resource_name}-configure-resource-access-policy"
  role   = aws_iam_role.configure_resource_access_role[0].id
  policy = local.configure_resource_access_policy
}

# Lambda Execution Role: Create Volume Snapshots
resource "aws_iam_role" "create_volume_snapshots_role" {
  count = local.enable_create_volume_snapshot ? 1 : 0
  name  = local.create_volume_snapshots_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.create_volume_snapshots_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "create-volume-snapshots-role"
  }
}

resource "aws_iam_role_policy_attachment" "create_volume_snapshots_basic" {
  count      = local.enable_create_volume_snapshot ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.create_volume_snapshots_role[0].name
}

resource "aws_iam_role_policy" "create_volume_snapshots_policy" {
  count  = local.enable_create_volume_snapshot ? 1 : 0
  name   = "${local.ra_resource_name}-create-volume-snapshots-policy"
  role   = aws_iam_role.create_volume_snapshots_role[0].id
  policy = local.create_volume_snapshots_policy
}

# Lambda Execution Role: Delete Volume Snapshots
resource "aws_iam_role" "delete_volume_snapshots_role" {
  count = local.enable_create_volume_snapshot ? 1 : 0
  name  = local.delete_volume_snapshots_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = local.delete_volume_snapshots_role_name
    "sysdig.com/response-actions/cloud-actions" = "true"
    "sysdig.com/response-actions/resource-name" = "delete-volume-snapshots-role"
  }
}

resource "aws_iam_role_policy_attachment" "delete_volume_snapshots_basic" {
  count      = local.enable_create_volume_snapshot ? 1 : 0
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.delete_volume_snapshots_role[0].name
}

resource "aws_iam_role_policy" "delete_volume_snapshots_policy" {
  count  = local.enable_create_volume_snapshot ? 1 : 0
  name   = "${local.ra_resource_name}-delete-volume-snapshots-policy"
  role   = aws_iam_role.delete_volume_snapshots_role[0].id
  policy = local.delete_volume_snapshots_policy
}

# Lambda Execution Role: Package Downloader (Global, used by all regions)
resource "aws_iam_role" "package_downloader_role" {
  name = "${local.ra_resource_name}-package-downloader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name                                        = "${local.ra_resource_name}-package-downloader-role"
    "sysdig.com/response-actions/resource-name" = "package-downloader-role"
  }
}

resource "aws_iam_role_policy_attachment" "package_downloader_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.package_downloader_role.name
}

resource "aws_iam_role_policy" "package_downloader_policy" {
  name = "${local.ra_resource_name}-package-downloader-policy"
  role = aws_iam_role.package_downloader_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject"
        ]
        Resource = "${local.arn_prefix}:s3:::${local.s3_bucket_name}-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "${local.arn_prefix}:s3:::${local.s3_bucket_name}-*"
      }
    ]
  })
}

# Wait for IAM role to propagate globally before using it
resource "time_sleep" "wait_for_iam_role_propagation" {
  depends_on = [
    aws_iam_role.package_downloader_role,
    aws_iam_role_policy.package_downloader_policy,
    aws_iam_role_policy_attachment.package_downloader_basic
  ]

  create_duration = "10s"
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# S3 Bucket for Lambda deployment packages
#
# The CloudFormation StackSet will create regional S3 buckets automatically in each deployed region.
# The bucket naming follows the pattern: {s3_bucket_name}-{region}
#
# A custom Lambda function (PackageDownloaderFunction) will download the Lambda zip files from the provided
# lambda_packages_base_url and upload them to the regional S3 buckets. The packages are downloaded from:
# {lambda_packages_base_url}/v{version}/{lambda_name}.zip
#
# Lambda packages downloaded:
# - quarantine_user.zip
# - fetch_cloud_logs.zip
# - remove_policy.zip
# - configure_resource_access.zip
# - create_volume_snapshots.zip
# - delete_volume_snapshots.zip
#-----------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------------------------
# This resource creates a stackset to deploy Response Action Lambda functions across multiple regions.
#
# The stackset creates Lambda functions in each specified region with the following configuration:
# 1. Lambda Functions - One per enabled response action, deployed from regional S3 buckets
# 2. CloudWatch Log Groups - For Lambda execution logs with retention policies
# 3. Function Configuration - Environment variables including API base URL and resource names
#
# The Lambda functions are deployed using deployment packages stored in regional S3 buckets. Each function
# assumes the corresponding IAM execution role created in the management account.
#
# Note: Self-managed stacksets require a pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles
# with self-managed permissions.
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "aws_cloudformation_stack_set" "lambda_functions" {
  name = "${local.ra_resource_name}-lambda"
  tags = merge(var.tags, {
    "sysdig.com/response-actions/resource-name" = "lambda-stackset"
  })
  permission_model        = "SELF_MANAGED"
  capabilities            = ["CAPABILITY_NAMED_IAM"]
  administration_role_arn = local.administration_role_arn
  execution_role_name     = local.execution_role_name

  managed_execution {
    active = true
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  parameters = {
    ResourceName                    = local.ra_resource_name
    TemplateVersion                 = md5(file("${path.module}/templates/lambda-stackset.tpl"))
    S3BucketName                    = local.s3_bucket_name
    ApiBaseUrl                      = var.api_base_url
    PackageDownloaderRoleArn        = aws_iam_role.package_downloader_role.arn
    QuarantineUserRoleArn           = local.enable_quarantine_user ? aws_iam_role.quarantine_user_role[0].arn : ""
    FetchCloudLogsRoleArn           = local.enable_fetch_cloud_logs ? aws_iam_role.fetch_cloud_logs_role[0].arn : ""
    RemovePolicyRoleArn             = local.enable_quarantine_user ? aws_iam_role.remove_policy_role[0].arn : ""
    ConfigureResourceAccessRoleArn  = local.enable_make_private ? aws_iam_role.configure_resource_access_role[0].arn : ""
    CreateVolumeSnapshotsRoleArn    = local.enable_create_volume_snapshot ? aws_iam_role.create_volume_snapshots_role[0].arn : ""
    DeleteVolumeSnapshotsRoleArn    = local.enable_create_volume_snapshot ? aws_iam_role.delete_volume_snapshots_role[0].arn : ""
    QuarantineUserRoleName          = local.enable_quarantine_user ? aws_iam_role.quarantine_user_role[0].name : ""
    FetchCloudLogsRoleName          = local.enable_fetch_cloud_logs ? aws_iam_role.fetch_cloud_logs_role[0].name : ""
    RemovePolicyRoleName            = local.enable_quarantine_user ? aws_iam_role.remove_policy_role[0].name : ""
    ConfigureResourceAccessRoleName = local.enable_make_private ? aws_iam_role.configure_resource_access_role[0].name : ""
    CreateVolumeSnapshotsRoleName   = local.enable_create_volume_snapshot ? aws_iam_role.create_volume_snapshots_role[0].name : ""
    DeleteVolumeSnapshotsRoleName   = local.enable_create_volume_snapshot ? aws_iam_role.delete_volume_snapshots_role[0].name : ""
    ResponseActionsVersion          = var.response_actions_version
    LambdaPackagesBaseUrl           = var.lambda_packages_base_url
    EnableQuarantineUser            = local.enable_quarantine_user ? "true" : "false"
    EnableFetchCloudLogs            = local.enable_fetch_cloud_logs ? "true" : "false"
    EnableMakePrivate               = local.enable_make_private ? "true" : "false"
    EnableCreateVolumeSnapshot      = local.enable_create_volume_snapshot ? "true" : "false"
  }

  template_body = file("${path.module}/templates/lambda-stackset.tpl")

  depends_on = [
    aws_iam_role.lambda_stackset_admin_role,
    aws_iam_role.lambda_stackset_execution_role,
    time_sleep.wait_for_iam_role_propagation
  ]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# StackSet instances to deploy Lambda functions in all specified regions.
#
# For each region in the region_set, this creates a stack instance that deploys the Lambda functions and their
# supporting resources. The deployment uses parallel execution across regions for faster rollout.
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "aws_cloudformation_stack_set_instance" "lambda_functions" {
  for_each                  = local.region_set
  stack_set_instance_region = each.key

  stack_set_name = aws_cloudformation_stack_set.lambda_functions.name

  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    region_concurrency_type      = "PARALLEL"
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  depends_on = [
    aws_iam_role_policy.lambda_stackset_execution_policy,
    aws_iam_role_policy_attachment.lambda_stackset_execution_cloudformation
  ]
}

resource "time_sleep" "wait_after_ciem_basic" {
  count           = var.wait_after_basic_seconds > 0 ? 1 : 0
  create_duration = local.wait_duration
}
