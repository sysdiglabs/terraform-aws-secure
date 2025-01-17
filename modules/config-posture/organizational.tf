#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  org_units_to_deploy = var.is_organizational && length(var.org_units) == 0 ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : var.org_units
}

#----------------------------------------------------------
# Since this is an Organizational deploy, use a CloudFormation StackSet
#----------------------------------------------------------

resource "aws_cloudformation_stack_set" "stackset" {
  count = var.is_organizational ? 1 : 0

  name             = local.config_posture_role_name
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
  SysdigCSPMRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ${local.config_posture_role_name}
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              AWS: [ ${local.trusted_identity} ]
            Action: [ 'sts:AssumeRole' ]
            Condition:
              StringEquals:
                sts:ExternalId: ${data.sysdig_secure_tenant_external_id.external_id.external_id}
      ManagedPolicyArns:
        - "${local.arn_prefix}:iam::aws:policy/SecurityAudit"
      Policies:
        - PolicyName: ${local.config_posture_role_name}
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Sid: "DescribeEFSAccessPoints"
                Effect: "Allow"
                Action: "elasticfilesystem:DescribeAccessPoints"
                Resource: "*"
              - Sid: "ListWafRegionalRulesAndRuleGroups"
                Effect: "Allow"
                Action:
                  - "waf-regional:ListRules"
                  - "waf-regional:ListRuleGroups"
                Resource:
                  - "${local.arn_prefix}:waf-regional:*:*:rule/*"
                  - "${local.arn_prefix}:waf-regional:*:*:rulegroup/*"
              - Sid: "ListJobsOnConsole"
                Effect: "Allow"
                Action: "macie2:ListClassificationJobs"
                Resource: "*"
              - Sid: "GetFunctionDetails"
                Effect: "Allow"
                Action:
                  - "lambda:GetRuntimeManagementConfig"
                  - "lambda:GetFunction"
                Resource: "*"
              - Sid: "AccessAccountContactInfo"
                Effect: "Allow"
                Action:
                  - "account:GetContactInformation"
                Resource: "*"
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
