data "sysdig_secure_tenant_external_id" "cloud_auth_external_id" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

###########################################
# Workload Controller IAM roles and stuff #
###########################################

#-----------------------------------------------------------------------------------------------------------------------
# Determine if this is an Organizational install, or a single account install. For Single Account installs, resources
# are created directly using the AWS Terraform Provider (This is the default behaviour). For Organizational installs,
# see organizational.tf, and the resources in this file are used to instrument the management account (StackSets do not
# include the management account they are created in, even if this account is within the target Organization).
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------
# These resources create an Agentless Workload Scanning IAM Role and IAM Policy in the account.
#-----------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "scanning" {
  # General ECR read permission, necessary for the fetching artifacts.
  statement {
    sid = "EcrReadPermissions"

    effect = "Allow"

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:ListImages",
      "ecr:GetAuthorizationToken",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "functions" {
  count = var.lambda_scanning_enabled ? 1 : 0

  statement {
    sid = "SysdigWorkloadFunctionsScanning"

    effect = "Allow"

    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetRuntimeManagementConfig",
      "lambda:ListFunctions",
      "lambda:ListTagsForResource",
      "lambda:GetLayerVersionByArn",
      "lambda:GetLayerVersion",
      "lambda:ListLayers",
      "lambda:ListLayerVersions"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "ecr_scanning" {
  count = var.is_organizational ? 0 : 1

  name        = "${local.ecr_role_name}-ecr"
  description = "Grants Sysdig Secure access to ECR images"
  policy      = data.aws_iam_policy_document.scanning.json
  tags        = var.tags
}

resource "aws_iam_policy" "functions_scanning" {
  count = var.lambda_scanning_enabled && !var.is_organizational? 1 : 0

  name        = "${local.ecr_role_name}-functions"
  description = "Grants Sysdig Secure access to AWS Lambda"
  policy      = data.aws_iam_policy_document.functions[0].json
  tags        = var.tags
}

data "aws_iam_policy_document" "scanning_assume_role_policy" {
  statement {
    sid = "SysdigWorkloadScanning"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"
      identifiers = [
        data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.sysdig_secure_tenant_external_id.cloud_auth_external_id.external_id]
    }
  }
}

resource "aws_iam_role" "scanning" {
  count = var.is_organizational ? 0 : 1

  name               = local.ecr_role_name
  tags               = var.tags
  assume_role_policy = data.aws_iam_policy_document.scanning_assume_role_policy.json
}

resource "aws_iam_policy_attachment" "scanning" {
  count = var.is_organizational ? 0 : 1

  name       = local.ecr_role_name
  roles      = [aws_iam_role.scanning[0].name]
  policy_arn = aws_iam_policy.ecr_scanning[0].arn
}

resource "aws_iam_policy_attachment" "functions" {
  count = var.lambda_scanning_enabled && !var.is_organizational ? 1 : 0

  name       = local.ecr_role_name
  roles      = [aws_iam_role.scanning[0].name]
  policy_arn = aws_iam_policy.functions_scanning[0].arn
}

#--------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the trusted role for Config Posture to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#--------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "vm_workload_scanning_account_component" {
  account_id = var.sysdig_secure_account_id

  type       = "COMPONENT_TRUSTED_ROLE"
  instance   = "secure-vm-workload-scanning"
  version    = "v0.1.0"
  trusted_role_metadata = jsonencode({
    aws = {
      role_name = aws_iam_role.scanning[0].name
    }
  })

  depends_on = [
    aws_iam_policy.ecr_scanning,
    aws_iam_role.scanning,
    aws_iam_policy_attachment.scanning,
    aws_cloudformation_stack_set.scanning_role_stackset,
    aws_cloudformation_stack_set_instance.scanning_role_stackset_instance,
    aws_iam_policy.functions_scanning,
    aws_iam_policy_attachment.functions,
  ]
}
