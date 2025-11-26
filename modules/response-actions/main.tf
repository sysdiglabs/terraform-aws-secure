data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  quarantine_user_policy           = templatefile("${path.module}/policies/quarantine-user-policy.json", {})
  fetch_cloud_logs_policy          = templatefile("${path.module}/policies/fetch-cloud-logs-policy.json", {})
  remove_policy_policy             = templatefile("${path.module}/policies/remove-policy-policy.json", {})
  configure_resource_access_policy = templatefile("${path.module}/policies/configure-resource-access-policy.json", {})
  create_volume_snapshots_policy   = templatefile("${path.module}/policies/create-volume-snapshots-policy.json", {})
  delete_volume_snapshots_policy   = templatefile("${path.module}/policies/delete-volume-snapshots-policy.json", {})

  # Use provided regions or default to current region
  region_set               = length(var.regions) > 0 ? toset(var.regions) : toset([data.aws_region.current.id])
  trusted_identity         = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix               = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
  responder_component_type = "COMPONENT_CLOUD_RESPONDER"
  roles_component_type     = "COMPONENT_CLOUD_RESPONDER_ROLES"
  account_id_hash          = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  ra_resource_name         = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"

  # StackSet role configuration
  administration_role_arn = var.auto_create_stackset_roles ? aws_iam_role.lambda_stackset_admin_role[0].arn : var.stackset_admin_role_arn
  execution_role_name     = var.auto_create_stackset_roles ? aws_iam_role.lambda_stackset_execution_role[0].name : var.stackset_execution_role_name
}

#------------------------------------------------------
# StackSet IAM Roles for multi-region deployment
#------------------------------------------------------

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
    Name = "${local.ra_resource_name}-stackset-admin"
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
        Resource = "arn:aws:iam::*:role/${local.ra_resource_name}-stackset-execution"
      }
    ]
  })
}

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
    Name = "${local.ra_resource_name}-stackset-execution"
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
          "cloudformation:*",
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
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "random_id" "suffix" {
  byte_length = 3
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}


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
    Name = "${local.ra_resource_name}-cross-account-invoker"
  }
}

# Inline policy for invoking all Lambda functions across all deployed regions
resource "aws_iam_role_policy" "shared_lambda_invoke_policy" {
  name = "${local.ra_resource_name}-invoke-policy"
  role = aws_iam_role.shared_cross_account_lambda_invoker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction"
        ]
        Resource = [
          # Quarantine User functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-quarantine-user",
          # Fetch Cloud Logs functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-fetch-cloud-logs",
          # Remove Policy functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-remove-policy",
          # Configure Resource Access functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-configure-resource-access",
          # Create Volume Snapshots functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-create-volume-snapshots",
          # Delete Volume Snapshots functions in all regions
          "${local.arn_prefix}:lambda:*:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-delete-volume-snapshots"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------
# IAM Roles for Lambda Functions (Global Resources)
#------------------------------------------------------

# Lambda Execution Role: Quarantine User
resource "aws_iam_role" "quarantine_user_role" {
  name = "${local.ra_resource_name}-quarantine-user-role"

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
    Name = "${local.ra_resource_name}-quarantine-user-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "quarantine_user_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.quarantine_user_role.name
}

resource "aws_iam_role_policy" "quarantine_user_policy" {
  name   = "${local.ra_resource_name}-quarantine-user-policy"
  role   = aws_iam_role.quarantine_user_role.id
  policy = local.quarantine_user_policy
}

# Lambda Execution Role: Fetch Cloud Logs
resource "aws_iam_role" "fetch_cloud_logs_role" {
  name = "${local.ra_resource_name}-fetch-cloud-logs-role"

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
    Name = "${local.ra_resource_name}-fetch-cloud-logs-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "fetch_cloud_logs_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.fetch_cloud_logs_role.name
}

resource "aws_iam_role_policy" "fetch_cloud_logs_policy" {
  name   = "${local.ra_resource_name}-fetch-cloud-logs-policy"
  role   = aws_iam_role.fetch_cloud_logs_role.id
  policy = local.fetch_cloud_logs_policy
}

# Lambda Execution Role: Remove Policy
resource "aws_iam_role" "remove_policy_role" {
  name = "${local.ra_resource_name}-remove-policy-role"

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
    Name = "${local.ra_resource_name}-remove-policy-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "remove_policy_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.remove_policy_role.name
}

resource "aws_iam_role_policy" "remove_policy_policy" {
  name   = "${local.ra_resource_name}-remove-policy-policy"
  role   = aws_iam_role.remove_policy_role.id
  policy = local.remove_policy_policy
}

# Lambda Execution Role: Configure Resource Access
resource "aws_iam_role" "configure_resource_access_role" {
  name = "${local.ra_resource_name}-configure-resource-access-role"

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
    Name = "${local.ra_resource_name}-configure-resource-access-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "configure_resource_access_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.configure_resource_access_role.name
}

resource "aws_iam_role_policy" "configure_resource_access_policy" {
  name   = "${local.ra_resource_name}-configure-resource-access-policy"
  role   = aws_iam_role.configure_resource_access_role.id
  policy = local.configure_resource_access_policy
}

# Lambda Execution Role: Create Volume Snapshots
resource "aws_iam_role" "create_volume_snapshots_role" {
  name = "${local.ra_resource_name}-create-volume-snapshots-role"

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
    Name = "${local.ra_resource_name}-create-volume-snapshots-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "create_volume_snapshots_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.create_volume_snapshots_role.name
}

resource "aws_iam_role_policy" "create_volume_snapshots_policy" {
  name   = "${local.ra_resource_name}-create-volume-snapshots-policy"
  role   = aws_iam_role.create_volume_snapshots_role.id
  policy = local.create_volume_snapshots_policy
}

# Lambda Execution Role: Delete Volume Snapshots
resource "aws_iam_role" "delete_volume_snapshots_role" {
  name = "${local.ra_resource_name}-delete-volume-snapshots-role"

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
    Name = "${local.ra_resource_name}-delete-volume-snapshots-role"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "delete_volume_snapshots_basic" {
  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.delete_volume_snapshots_role.name
}

resource "aws_iam_role_policy" "delete_volume_snapshots_policy" {
  name   = "${local.ra_resource_name}-delete-volume-snapshots-policy"
  role   = aws_iam_role.delete_volume_snapshots_role.id
  policy = local.delete_volume_snapshots_policy
}

#------------------------------------------------------
# S3 Bucket for Lambda deployment packages
#------------------------------------------------------

resource "aws_s3_bucket" "lambda_deployment" {
  bucket = "${local.ra_resource_name}-lambda-deployment"

  tags = {
    Name = "${local.ra_resource_name}-lambda-deployment"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

resource "aws_s3_bucket_versioning" "lambda_deployment" {
  bucket = aws_s3_bucket.lambda_deployment.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Download Lambda ZIP files
data "http" "quarantine_user_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/quarantine_user.zip"
}

data "http" "fetch_cloud_logs_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/fetch_cloud_logs.zip"
}

data "http" "remove_policy_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/remove_policy.zip"
}

data "http" "configure_resource_access_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/configure_resource_access.zip"
}

data "http" "create_volume_snapshot_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/create_volume_snapshot.zip"
}

data "http" "delete_volume_snapshot_zip" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/delete_volume_snapshot.zip"
}

# Upload Lambda ZIP files to S3
resource "aws_s3_object" "quarantine_user_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "quarantine_user.zip"
  content_base64 = data.http.quarantine_user_zip.response_body_base64
  content_type   = "application/zip"
}

resource "aws_s3_object" "fetch_cloud_logs_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "fetch_cloud_logs.zip"
  content_base64 = data.http.fetch_cloud_logs_zip.response_body_base64
  content_type   = "application/zip"
}

resource "aws_s3_object" "remove_policy_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "remove_policy.zip"
  content_base64 = data.http.remove_policy_zip.response_body_base64
  content_type   = "application/zip"
}

resource "aws_s3_object" "configure_resource_access_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "configure_resource_access.zip"
  content_base64 = data.http.configure_resource_access_zip.response_body_base64
  content_type   = "application/zip"
}

resource "aws_s3_object" "create_volume_snapshot_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "create_volume_snapshot.zip"
  content_base64 = data.http.create_volume_snapshot_zip.response_body_base64
  content_type   = "application/zip"
}

resource "aws_s3_object" "delete_volume_snapshot_zip" {
  bucket         = aws_s3_bucket.lambda_deployment.id
  key            = "delete_volume_snapshot.zip"
  content_base64 = data.http.delete_volume_snapshot_zip.response_body_base64
  content_type   = "application/zip"
}

#------------------------------------------------------
# CloudFormation StackSet for Multi-Region Lambda Deployment
#------------------------------------------------------

resource "aws_cloudformation_stack_set" "lambda_functions" {
  name                    = "${local.ra_resource_name}-lambda"
  tags                    = var.tags
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
    S3Bucket                        = aws_s3_bucket.lambda_deployment.id
    ApiBaseUrl                      = var.api_base_url
    QuarantineUserRoleArn           = aws_iam_role.quarantine_user_role.arn
    FetchCloudLogsRoleArn           = aws_iam_role.fetch_cloud_logs_role.arn
    RemovePolicyRoleArn             = aws_iam_role.remove_policy_role.arn
    ConfigureResourceAccessRoleArn  = aws_iam_role.configure_resource_access_role.arn
    CreateVolumeSnapshotsRoleArn    = aws_iam_role.create_volume_snapshots_role.arn
    DeleteVolumeSnapshotsRoleArn    = aws_iam_role.delete_volume_snapshots_role.arn
    QuarantineUserRoleName          = aws_iam_role.quarantine_user_role.name
    FetchCloudLogsRoleName          = aws_iam_role.fetch_cloud_logs_role.name
    RemovePolicyRoleName            = aws_iam_role.remove_policy_role.name
    ConfigureResourceAccessRoleName = aws_iam_role.configure_resource_access_role.name
    CreateVolumeSnapshotsRoleName   = aws_iam_role.create_volume_snapshots_role.name
    DeleteVolumeSnapshotsRoleName   = aws_iam_role.delete_volume_snapshots_role.name
  }

  template_body = file("${path.module}/templates/lambda-stackset.yaml")

  depends_on = [
    aws_iam_role.lambda_stackset_admin_role,
    aws_iam_role.lambda_stackset_execution_role,
    aws_s3_object.quarantine_user_zip,
    aws_s3_object.fetch_cloud_logs_zip,
    aws_s3_object.remove_policy_zip,
    aws_s3_object.configure_resource_access_zip,
    aws_s3_object.create_volume_snapshot_zip,
    aws_s3_object.delete_volume_snapshot_zip
  ]
}

# StackSet instances to deploy Lambda functions in all specified regions
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
}
