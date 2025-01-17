#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  org_units_to_deploy = var.is_organizational && length(var.organizational_unit_ids) == 0 ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : var.organizational_unit_ids
}

#----------------------------------------------------------
# Since this is an Organizational deploy, use a CloudFormation StackSet
#----------------------------------------------------------

resource "aws_cloudformation_stack_set" "stackset" {
  count = var.is_organizational ? 1 : 0

  name             = local.onboarding_role_name
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

  template_body = <<TEMPLATE
Resources:
  SysdigOnboardingRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ${local.onboarding_role_name}
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              AWS: [ ${local.trusted_identity} ]
            Action: [ 'sts:AssumeRole' ]
            Condition:
              StringEquals:
                sts:ExternalId: ${data.sysdig_secure_tenant_external_id.external_id.external_id}
      Policies:
          - PolicyName: ${local.onboarding_role_name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Effect: Allow
                  Action:
                    - "account:Get*"
                    - "account:List*"
                  Resource: "*"
      ManagedPolicyArns:
        - "${local.arn_prefix}:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
TEMPLATE
}

resource "aws_cloudformation_stack_set_instance" "stackset_instance" {
  count = var.is_organizational ? 1 : 0

  region         = var.region == "" ? null : var.region
  stack_set_name = aws_cloudformation_stack_set.stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.org_units_to_deploy
    account_filter_type     = "DIFFERENCE"
    accounts                = var.organization_accounts_to_exclude
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    # Roles are not regional and hence do not need regional parallelism
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}

resource "sysdig_secure_organization" "aws_organization" {
  count                   = var.is_organizational ? 1 : 0
  management_account_id   = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  organizational_unit_ids = var.organizational_unit_ids
}
