#-----------------------------------------------------------------------------------------------------------------------
# For both Single Account and Organizational installs, resources are created using CloudFormation StackSet.
# For Organizational installs, see organizational.tf. The resources in this file are used to instrument the singleton
# account including the management account (StackSets do not include the management account they are create in,
# even if this account is within the target Organization).
#
# For single installs, resources in this file get created whether they are management account or a member account.
# (delegated admin account is a noop here for single installs)
#
# For organizational installs, resources in this file get created for management account only.
# If a delegated admin account is used (determined via var.delegated_admin flag), resources will skip creation.
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
	cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#-----------------------------------------------------------------------------------------------------------------------
# These locals indicate the region list passed.
#-----------------------------------------------------------------------------------------------------------------------
locals {
  region_set = toset(var.regions)
}

#-----------------------------------------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------------------------------------
locals {
  account_id_hash  = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  eb_resource_name = "${var.name}-${random_string.random.result}-${local.account_id_hash}"
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique Event Bridge name for resources.
# This prevents conflicts when recreating an Event Bridge resources with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets. If false, and values for stackset Admin role ARN is provided stackset will use it, else AWS will look for
# predefined/default AWSCloudFormationStackSetAdministrationRole.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_stackset_admin_role" {
  count = var.delegated_admin || !var.auto_create_stackset_roles ? 0 : 1
  name  = "AWSCloudFormationStackSetAdministrationRoleForEB"
  tags  = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets, Event Bridge resources and trust relationship to CloudFormation service. If false, and values for stackset Execution role
# name is provided stackset will use it, else AWS will look for predefined/default AWSCloudFormationStackSetExecutionRole.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_stackset_execution_role" {
  count      = var.delegated_admin || !var.auto_create_stackset_roles ? 0 : 1
  name       = "AWSCloudFormationStackSetExecutionRoleForEB"
  tags       = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.event_bus_stackset_admin_role[0].name}"
      },
      "Effect": "Allow",
      "Condition": {}
    }
  ]
}
EOF
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",
    "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
  ]

  depends_on = [aws_iam_role.event_bus_stackset_admin_role]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# These resources create an IAM role in the source account with permissions to call PutEvent on the EventBridge Bus in
# Sysdig's AWS account. This role is attached to the EventBridge target that is created in the source account.
#
# This role will be used by EventBridge when sending events to Sysdig's EventBridge Bus. The EventBridge service is
# given permission to assume this role.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_invoke_remote_event_bus" {
  count = var.delegated_admin ? 0 : 1
  name  = local.eb_resource_name
  tags  = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow"
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}"
      },
      "Effect": "Allow",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${data.sysdig_secure_tenant_external_id.external_id.external_id}"
        }
      }
    }
  ]
}
EOF
  inline_policy {
    name   = local.eb_resource_name
    policy = data.aws_iam_policy_document.cloud_trail_events.json
  }
}

# IAM Policy Document used by EventBridge role for the cloudtrail events policy
data "aws_iam_policy_document" "cloud_trail_events" {

  statement {
    sid = "CloudTrailEventsPut"

    effect = "Allow"

    actions = [
      "events:PutEvents",
    ]

    resources = [
      data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARN,
    ]
  }

  statement {
    sid = "CloudTrailEventRuleAccess"

    effect = "Allow"

    actions = [
      "events:DescribeRule",
      "events:ListTargetsByRule",
    ]

    resources = [
      "arn:aws:events:*:*:rule/${local.eb_resource_name}",
    ]
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# This resource creates a stackset to set up an EventBridge Rule and Target to forward all CloudTrail events from the
# source account to Sysdig. CloudTrail events are sent to the default EventBridge Bus in the source account automatically.
#
# Rule captures all events from CloudTrail in the source account.
# Target forwards all CloudTrail events to Sysdig's EventBridge Bus.
# See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target#cross-account-event-bus-target
#
# Note: self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions 
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_cloudformation_stack_set" "single-acc-stackset" {
  count                   = var.delegated_admin ? 0 : 1
  name                    = join("-", [local.eb_resource_name, "EBRuleSingleAcc"])
  tags                    = var.tags
  permission_model        = "SELF_MANAGED"
  capabilities            = ["CAPABILITY_NAMED_IAM"]
  administration_role_arn = var.auto_create_stackset_roles ? aws_iam_role.event_bus_stackset_admin_role[0].arn : var.stackset_admin_role_arn
  execution_role_name     = var.auto_create_stackset_roles ? aws_iam_role.event_bus_stackset_execution_role[0].name : var.stackset_execution_role_name

  managed_execution {
    active = true
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  template_body = templatefile("${path.module}/stackset_template_body.tpl", {
    name                 = local.eb_resource_name
    event_pattern        = var.event_pattern
    rule_state           = var.rule_state
    target_event_bus_arn = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARN
  })

  depends_on = [
    aws_iam_role.event_bus_invoke_remote_event_bus,
    aws_iam_role.event_bus_stackset_admin_role,
    aws_iam_role.event_bus_stackset_execution_role
  ]
}

// stackset instance to deploy rule in all regions of single account
resource "aws_cloudformation_stack_set_instance" "single_acc_stackset_instance" {
  for_each       = var.delegated_admin ? toset([]) : local.region_set
  region         = each.key
  stack_set_name = aws_cloudformation_stack_set.single-acc-stackset[0].name

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

#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the event-bridge integration to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "sysdig_secure_cloud_auth_account_component" "aws_event_bridge" {
  account_id                 = var.sysdig_secure_account_id
  type                       = "COMPONENT_EVENT_BRIDGE"
  instance                   = "secure-runtime"
  event_bridge_metadata = jsonencode({
    aws = {
      role_name = local.eb_resource_name
      rule_name = local.eb_resource_name
      #TODO: regions once support added
    }
  })
}