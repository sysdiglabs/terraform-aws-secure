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

// generate a random suffix for the onboarding role name
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  onboarding_role_name = "sysdig-secure-onboarding-${random_id.suffix.hex}"
  trusted_identity     = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix           = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
}

#----------------------------------------------------------
# Since this is not an Organizational deploy, create role/polices directly
#----------------------------------------------------------
resource "aws_iam_role" "onboarding_role" {
  name               = local.onboarding_role_name
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

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_iam_role_policy" "onboarding_role_policy" {
  name = local.onboarding_role_name
  role = aws_iam_role.onboarding_role.id
  policy = jsonencode({
    Statement = [
      {
        Sid = "AccountManagementReadAccess"
        Action = [
          "account:Get*",
          "account:List*",
          "iam:ListAccountAliases",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachments_exclusive" "onboarding_role_managed_policy" {
  count     = var.is_organizational ? 1 : 0
  role_name = aws_iam_role.onboarding_role.id
  policy_arns = [
    "${local.arn_prefix}:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
  ]
}

data "aws_caller_identity" "current" {}

resource "sysdig_secure_cloud_auth_account" "cloud_auth_account" {
  enabled            = true
  provider_id        = data.aws_caller_identity.current.account_id
  provider_type      = "PROVIDER_AWS"
  provider_alias     = var.account_alias
  provider_partition = var.is_gov_cloud_onboarding ? "PROVIDER_PARTITION_AWS_GOVCLOUD" : ""

  component {
    type     = "COMPONENT_TRUSTED_ROLE"
    instance = "secure-onboarding"
    version  = "v0.1.0"
    trusted_role_metadata = jsonencode({
      aws = {
        role_name = local.onboarding_role_name
      }
    })
  }

  lifecycle { # features and components are managed outside this module
    ignore_changes = [
      component,
      feature
    ]
  }

  depends_on = [
    aws_iam_role_policy.onboarding_role_policy,
    aws_cloudformation_stack_set_instance.stackset_instance
  ]
}
