#----------------------------------------------------------
# Since this is an Organizational deploy, use a CloudFormation StackSet
#----------------------------------------------------------

resource "aws_cloudformation_stack_set" "stackset" {
  count = var.is_organizational ? 1 : 0

  name             = local.onboarding_role_name
  tags             = var.tags
  permission_model = "SERVICE_MANAGED"
  capabilities = ["CAPABILITY_NAMED_IAM"]

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
  for_each = var.is_organizational ? toset(local.deployment_targets_org_units) : []

  region         = var.region == "" ? null : var.region
  stack_set_name = aws_cloudformation_stack_set.stackset[0].name
  deployment_targets {
    organizational_unit_ids = [each.value]
    accounts                = local.check_old_ouid_param ? null : (local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy)
    account_filter_type     = local.check_old_ouid_param ? null : local.deployment_targets_accounts_filter
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
  count                          = var.is_organizational ? 1 : 0
  management_account_id          = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  organizational_unit_ids        = local.check_old_ouid_param ? var.organizational_unit_ids : []
  organization_root_id           = local.root_org_unit[0]
  included_organizational_groups = local.check_old_ouid_param ? [] : var.include_ouids
  excluded_organizational_groups = local.check_old_ouid_param ? [] : var.exclude_ouids
  included_cloud_accounts        = local.check_old_ouid_param ? [] : var.include_accounts
  excluded_cloud_accounts        = local.check_old_ouid_param ? [] : var.exclude_accounts
  automatic_onboarding           = var.enable_automatic_onboarding

  lifecycle {
    ignore_changes = [automatic_onboarding]
  }
}
