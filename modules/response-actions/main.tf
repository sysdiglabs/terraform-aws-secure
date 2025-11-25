data "aws_caller_identity" "current" {}

locals {
  quarantine_user_policy           = templatefile("${path.module}/policies/quarantine-user-policy.json", {})
  fetch_cloud_logs_policy          = templatefile("${path.module}/policies/fetch-cloud-logs-policy.json", {})
  remove_policy_policy             = templatefile("${path.module}/policies/remove-policy-policy.json", {})
  configure_resource_access_policy = templatefile("${path.module}/policies/configure-resource-access-policy.json", {})
  create_volume_snapshots_policy   = templatefile("${path.module}/policies/create-volume-snapshots-policy.json", {})
  delete_volume_snapshots_policy   = templatefile("${path.module}/policies/delete-volume-snapshots-policy.json", {})

  region_set               = toset(var.regions)
  trusted_identity         = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix               = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
  responder_component_type = "COMPONENT_CLOUD_RESPONDER"
  roles_component_type     = "COMPONENT_CLOUD_RESPONDER_ROLES"
  account_id_hash          = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  ra_resource_name         = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
  common_environment_variables = {
    API_BASE_URL = var.api_base_url
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}


resource "aws_iam_role" "shared_cross_account_lambda_invoker" {
  name = "${ra_resource_name}-cross-account-invoker"

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
    Name = "${ra_resource_name}-cross-account-invoker"
  }
}

# Inline policy for invoking all Lambda functions
resource "aws_iam_role_policy" "shared_lambda_invoke_policy" {
  name = "${ra_resource_name}-invoke-policy"
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
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-quarantine-user",
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-fetch-cloud-logs",
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-remove-policy",
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-configure-resource-access",
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-create-volume-snapshots",
          "${arn_prefix}:lambda:*:*:function:${ra_resource_name}-delete-volume-snapshots"
        ]
      },
      {
        Effect : "Allow"
        Action : [
          "tag:GetResources"
        ]
        Resource : "*"
      }
    ]
  })
}

# Lambda Function: Quarantine User
module "quarantine_user_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-quarantine-user"
  function_zip_file        = "quarantine_user.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.quarantine_user_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

# Lambda Function: Fetch cloud logs
module "fetch_cloud_logs_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-fetch-cloud-logs"
  function_zip_file        = "fetch_cloud_logs.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.fetch_cloud_logs_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

# Lambda Function: Remove Policy
module "remove_policy_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-remove-policy"
  function_zip_file        = "remove_policy.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.remove_policy_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

# Lambda Function: Configure Resource Access
module "configure_resource_access_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-configure-resource-access"
  function_zip_file        = "configure_resource_access.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.configure_resource_access_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

# Lambda Function: Create Volume Snapshots
module "create_volume_snapshots_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-create-volume-snapshots"
  function_zip_file        = "create_volume_snapshot.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.create_volume_snapshots_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

# Lambda Function: Delete Volume Snapshots
module "delete_volume_snapshots_function" {
  source = "./modules/lambda-functions"

  function_name            = "${ra_resource_name}-delete-volume-snapshots"
  function_zip_file        = "delete_volume_snapshot.zip"
  environment_variables    = local.common_environment_variables
  function_policies        = [local.delete_volume_snapshots_policy]
  lambda_handler           = "app.index.handler"
  response_actions_version = var.response_actions_version
  arn_prefix               = local.arn_prefix
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
