#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

// generate a random suffix for the onboarding role name
resource "random_id" "suffix" {
  byte_length = 3
}

data "aws_organizations_organization" "org" {
  count = var.organizational ? 1 : 0
}

locals {
  onboarding_role_name = "sysdig-secure-onboarding-${random_id.suffix.hex}"
  org_units_to_deploy  = var.is_organizational && length(var.org_units) == 0 ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : var.org_units
}

#----------------------------------------------------------
# If this is not an Organizational deploy, create role/polices directly
#----------------------------------------------------------
resource "aws_iam_role" "onboarding_role" {
  count              = var.delegated_admin ? 0 : 1
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
                "AWS": "${var.trusted_identity}"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${var.external_id}"
                }
            }
        }
    ]
}
EOF
  managed_policy_arns = compact([
    "arn:aws:iam::aws:policy/AWSAccountManagementReadOnlyAccess",
    var.organizational ? "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess" : ""
  ])

  lifecycle {
    ignore_changes = [ tags ]
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

#----------------------------------------------------------
# If this is an Organizational deploy, use a CloudFormation StackSet
#----------------------------------------------------------

resource "aws_cloudformation_stack_set" "stackset" {
  count = var.organizational ? 1 : 0

  name             = var.role_name
  tags             = var.tags
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]

  managed_execution {
    active = true
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  call_as = var.delegated_admin ? "DELEGATED_ADMIN" : "SELF"

  template_body = <<TEMPLATE
Resources:
  SysdigOnboardingRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ${var.role_name}
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              AWS: [ ${var.trusted_identity} ]
            Action: [ 'sts:AssumeRole' ]
            Condition:
              StringEquals:
                sts:ExternalId: ${var.external_id}
      ManagedPolicyArns:
        - "arn:aws:iam::aws:policy/AWSAccountManagementReadOnlyAccess"
        - "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
TEMPLATE
}

resource "aws_cloudformation_stack_set_instance" "stackset_instance" {
  count = var.organizational ? 1 : 0

  region         = var.region == "" ? null : var.region
  stack_set_name = aws_cloudformation_stack_set.stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.organizational_unit_ids
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    # Roles are not regional and hence do not need regional parallelism
  }

  call_as = var.delegated_admin ? "DELEGATED_ADMIN" : "SELF"

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}

resource "sysdig_secure_organization" "aws_organization" {
  count = var.organizational ? 1 : 0
  management_account_id = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  organizational_unit_ids  = var.organizational_unit_ids
}
