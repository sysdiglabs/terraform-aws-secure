#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

// generate a random suffix for the onboarding role name
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  onboarding_role_name = "sysdig-secure-onboarding-${random_id.suffix.hex}"
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

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
  managed_policy_arns = compact([
    "arn:aws:iam::aws:policy/AWSAccountManagementReadOnlyAccess",
    var.is_organizational ? "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess" : ""
  ])

  lifecycle {
    ignore_changes = [tags]
  }
}

data "aws_caller_identity" "current" {}
data "aws_iam_account_alias" "current" {}

resource "sysdig_secure_cloud_auth_account" "cloud_auth_account" {
  enabled        = true
  provider_id    = data.aws_caller_identity.current.account_id
  provider_type  = "PROVIDER_AWS"
  provider_alias = data.aws_iam_account_alias.current.account_alias

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
}
