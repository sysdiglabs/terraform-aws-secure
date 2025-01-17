#-----------------------------------------------------------------------------------------------------------------------
# These resources set up an EventBridge Rule and Target to forward all CloudTrail events from the source account to
# Sysdig in all accounts in an AWS Organization via service-managed CloudFormation StackSets.
# For a single account installation, see main.tf.
#-----------------------------------------------------------------------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  organizational_unit_ids = var.is_organizational && length(var.org_units) == 0 ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : toset(var.org_units)
}

# stackset to deploy eventbridge rule in organization unit
resource "aws_cloudformation_stack_set" "eb-rule-stackset" {
  count = var.is_organizational ? 1 : 0

  name             = join("-", [local.eb_resource_name, "EBRuleOrg"])
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

  template_body = templatefile("${path.module}/stackset_template_body.tpl", {
    name                 = local.eb_resource_name
    event_pattern        = var.event_pattern
    rule_state           = var.rule_state
    arn_prefix           = local.arn_prefix
    target_event_bus_arn = local.target_event_bus_arn
  })
}

# stackset to deploy eventbridge role in organization unit
resource "aws_cloudformation_stack_set" "eb-role-stackset" {
  count = var.is_organizational ? 1 : 0

  name             = join("-", [local.eb_resource_name, "EBRoleOrg"])
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
  EventBridgeRole:
      Type: AWS::IAM::Role
      Properties:
        RoleName: ${local.eb_resource_name}
        AssumeRolePolicyDocument:
          Version: "2012-10-17"
          Statement:
            - Effect: Allow
              Principal:
                Service: events.amazonaws.com
              Action: 'sts:AssumeRole'
            - Effect: "Allow"
              Principal:
                AWS: "${local.trusted_identity}"
              Action: "sts:AssumeRole"
              Condition:
                StringEquals:
                  sts:ExternalId: "${data.sysdig_secure_tenant_external_id.external_id.external_id}"
        Policies:
          - PolicyName: ${local.eb_resource_name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Effect: Allow
                  Action: 'events:PutEvents'
                  Resource: "${local.target_event_bus_arn}"
                - Effect: Allow
                  Action:
                    - "events:DescribeRule"
                    - "events:ListTargetsByRule"
                  Resource: "${local.arn_prefix}:events:*:*:rule/${local.eb_resource_name}"
TEMPLATE
}

// stackset instance to deploy rule in all organization units
resource "aws_cloudformation_stack_set_instance" "eb_rule_stackset_instance" {
  for_each = var.is_organizational ? local.region_set : toset([])
  region   = each.key

  stack_set_name = aws_cloudformation_stack_set.eb-rule-stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.organizational_unit_ids
    account_filter_type     = "DIFFERENCE"
    accounts                = var.organization_accounts_to_exclude
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    region_concurrency_type      = "PARALLEL"
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}

// stackset instance to deploy role in all organization units
resource "aws_cloudformation_stack_set_instance" "eb_role_stackset_instance" {
  count = var.is_organizational ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.eb-role-stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.organizational_unit_ids
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
