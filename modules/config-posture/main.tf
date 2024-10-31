#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

// generate a random suffix for the config-posture role name
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  config_posture_role_name = "sysdig-secure-posture-${random_id.suffix.hex}"
  trusted_identity         = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix               = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
}

#----------------------------------------------------------
# Since this is not an Organizational deploy, create role/polices directly
#----------------------------------------------------------
resource "aws_iam_role" "cspm_role" {
  name               = local.config_posture_role_name
  tags               = var.tags
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${local.trusted_identity}"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${data.sysdig_secure_tenant_external_id.external_id.external_id}"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachments_exclusive" "cspm_role_managed_policy" {
  role_name = aws_iam_role.cspm_role.id
  policy_arns = [
    "${local.arn_prefix}:iam::aws:policy/SecurityAudit"
  ]
}

resource "aws_iam_role_policy" "cspm_role_policy" {
  name = local.config_posture_role_name
  role = aws_iam_role.cspm_role.id
  policy = jsonencode({
    Statement = [
      {
        Sid = "DescribeEFSAccessPoints"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "ListWafRegionalRulesAndRuleGroups"
        Action = [
          "waf-regional:ListRules",
          "waf-regional:ListRuleGroups",
        ]
        Effect = "Allow"
        Resource = [
          "${local.arn_prefix}:waf-regional:*:*:rule/*",
          "${local.arn_prefix}:waf-regional:*:*:rulegroup/*"
        ]
      },
      {
        Sid      = "ListJobsOnConsole"
        Action   = "macie2:ListClassificationJobs"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "GetFunctionDetails"
        Action = [
          "lambda:GetRuntimeManagementConfig",
          "lambda:GetFunction",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid      = "AccessAccountContactInfo"
        Action   = "account:GetContactInformation"
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
#--------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the trusted role for Config Posture to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#--------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "config_posture_role" {
  account_id = var.sysdig_secure_account_id
  type       = "COMPONENT_TRUSTED_ROLE"
  instance   = "secure-posture"
  version    = "v0.1.0"
  trusted_role_metadata = jsonencode({
    aws = {
      role_name = local.config_posture_role_name
    }
  })
}