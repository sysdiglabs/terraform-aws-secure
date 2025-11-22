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
              - Sid: "ListAgents"
                Effect: "Allow"
                Action: "bedrock:ListAgents"
                Resource: "*"
              - Sid: "GetAgent"
                Effect: "Allow"
                Action: "bedrock:GetAgent"
                Resource: "*"
              - Sid: "ListKnowledgeBases"
                Effect: "Allow"
                Action: "bedrock:ListKnowledgeBases"
                Resource: "*"
              - Sid: "GetKnowledgeBase"
                Effect: "Allow"
                Action: "bedrock:GetKnowledgeBase"
                Resource: "*"
              - Sid: "ListGuardrails"
                Effect: "Allow"
                Action: "bedrock:ListGuardrails"
                Resource: "*"
              - Sid: "GetGuardrail"
                Effect: "Allow"
                Action: "bedrock:GetGuardrail"
                Resource: "*"
              - Sid: "GetModelInvocationLoggingConfiguration"
                Effect: "Allow"
                Action: "bedrock:GetModelInvocationLoggingConfiguration"
                Resource: "*"
TEMPLATE
}

resource "aws_cloudformation_stack_set_instance" "stackset_instance" {
  for_each = var.is_organizational ? toset(local.deployment_targets_org_units) : []

  stack_set_instance_region = var.region == "" ? null : var.region
  stack_set_name            = aws_cloudformation_stack_set.stackset[0].name
  deployment_targets {
    organizational_unit_ids = [each.value]
    accounts                = local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy
    account_filter_type     = local.deployment_targets_accounts_filter
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
