#-----------------------------------------------------------------------------------------------------------------------
# These resources set up an EventBridge Rule and Target to forward all CloudTrail events from the source account to
# Sysdig in all accounts in an AWS Organization via service-managed CloudFormation StackSets.
# For a single account installation, see main.tf.
#
# If a delegated admin account is used (determined via delegated_admin flag), service-managed stacksets will be created
# acting as delegated_admin to deploy resources in all acocunts within AWS Organization.
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

  call_as = var.delegated_admin ? "DELEGATED_ADMIN" : "SELF"

  template_body = templatefile("${path.module}/stackset_template_body.tpl", {
    name                 = local.eb_resource_name
    event_pattern        = var.event_pattern
    rule_state           = var.rule_state
    target_event_bus_arn = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARN
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

  call_as = var.delegated_admin ? "DELEGATED_ADMIN" : "SELF"

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
                AWS: "${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}"
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
                  Resource: ${data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARN}
                - Effect: Allow
                  Action:
                    - "events:DescribeRule"
                    - "events:ListTargetsByRule"
                  Resource: "arn:aws:events:*:*:rule/${local.eb_resource_name}"
TEMPLATE
}

// stackset instance to deploy rule in all organization units
resource "aws_cloudformation_stack_set_instance" "eb_rule_stackset_instance" {
  for_each = var.is_organizational ? local.region_set : toset([])
  region   = each.key

  stack_set_name = aws_cloudformation_stack_set.eb-rule-stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.organizational_unit_ids
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    region_concurrency_type      = "PARALLEL"
  }

  call_as = var.delegated_admin ? "DELEGATED_ADMIN" : "SELF"

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
