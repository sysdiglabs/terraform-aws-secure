// generate a random suffix for the config-posture role name

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  config_posture_role_name = "sysdig-secure-posture-${random_id.suffix.hex}"
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
	cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#----------------------------------------------------------
# Since this is not an Organizational deploy, create role/polices directly
#----------------------------------------------------------
resource "aws_iam_role" "cspm_role" {
  name                = local.config_posture_role_name
  tags                = var.tags
  assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}"
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
  managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
  inline_policy {
    name   = local.config_posture_role_name
    policy = data.aws_iam_policy_document.custom_resources_policy.json
  }
}

# Custom IAM Policy Document used by trust-relationship role
data "aws_iam_policy_document" "custom_resources_policy" {

  statement {
    sid = "DescribeEFSAccessPoints"

    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeAccessPoints",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "ListWafRegionalRulesAndRuleGroups"

    effect = "Allow"

    actions = [
      "waf-regional:ListRules",
      "waf-regional:ListRuleGroups",
    ]

    resources = [
      "arn:aws:waf-regional:*:*:rule/*",
      "arn:aws:waf-regional:*:*:rulegroup/*"
    ]
  }

  statement {
    sid = "ListJobsOnConsole"

    effect = "Allow"

    actions = [
      "macie2:ListClassificationJobs",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "GetFunctionDetails"

    effect = "Allow"

    actions = [
      "lambda:GetRuntimeManagementConfig",
      "lambda:GetFunction",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "AccessAccountContactInfo"

    effect = "Allow"

    actions = [
      "account:GetContactInformation",
    ]

    resources = [
      "*",
    ]
  }
}

#--------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the trusted role for Config Posture to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#--------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "config_posture_role" {
  account_id                 = var.sysdig_secure_account_id
  type                       = "COMPONENT_TRUSTED_ROLE"
  instance                   = "secure-posture"
  version                    = "v0.1.0"
  trusted_role_metadata = jsonencode({
        aws = {
          role_name = local.config_posture_role_name
        }
      })
}