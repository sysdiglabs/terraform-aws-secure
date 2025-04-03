#-----------------------------------------------------------------------------------------------------------------------------------------
# For both Single Account and Organizational installs, resources are created using CloudFormation StackSet.
# For Organizational installs, see organizational.tf.
#
# For single installs, the resources in this file are used to instrument the singleton account, whether it is a management account or a
# member account.
#
# For organizational installs, resources in this file get created for management account only. (because service-managed stacksets do not
# include the management account they are created in, even if this account is within the target Organization).
#-----------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# Fetch the data sources
#-----------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#-----------------------------------------------------------------------------------------
# These locals indicate the region list passed.
#-----------------------------------------------------------------------------------------
locals {
  region_set           = toset(var.regions)
  trusted_identity     = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  target_event_bus_arn = var.is_gov_cloud_onboarding ? data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARNGov : data.sysdig_secure_cloud_ingestion_assets.assets.aws.eventBusARN
  arn_prefix           = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
}

#-----------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------
locals {
  account_id_hash  = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  eb_resource_name = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique Event Bridge name suffix for resources.
# This prevents conflicts when recreating an Event Bridge resources with the same name.
#-----------------------------------------------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets. If false, and values for stackset Admin role ARN is provided stackset will use it, else AWS will look for
# predefined/default AWSCloudFormationStackSetAdministrationRole.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_stackset_admin_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "AWSCloudFormationStackSetAdministrationRoleForEB"
  tags = var.tags

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
}

resource "aws_iam_role_policy_attachments_exclusive" "event_bus_stackset_admin_role_managed_policy" {
  count     = !var.auto_create_stackset_roles ? 0 : 1
  role_name = aws_iam_role.event_bus_stackset_admin_role[0].id
  policy_arns = [
    "${local.arn_prefix}:iam::aws:policy/AWSCloudFormationFullAccess"
  ]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets, Event Bridge resources and trust relationship to CloudFormation service. If false, and values for stackset Execution role
# name is provided stackset will use it, else AWS will look for predefined/default AWSCloudFormationStackSetExecutionRole.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_stackset_execution_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "AWSCloudFormationStackSetExecutionRoleForEB"
  tags = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${local.arn_prefix}:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.event_bus_stackset_admin_role[0].name}"
      },
      "Effect": "Allow",
      "Condition": {}
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachments_exclusive" "event_bus_stackset_execution_role_managed_policy" {
  count     = !var.auto_create_stackset_roles ? 0 : 1
  role_name = aws_iam_role.event_bus_stackset_execution_role[0].id
  policy_arns = [
    "${local.arn_prefix}:iam::aws:policy/AWSCloudFormationFullAccess",
    "${local.arn_prefix}:iam::aws:policy/AmazonEventBridgeFullAccess"
  ]
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# These resources create an IAM role in the source account with permissions to call PutEvent on the EventBridge Bus in
# Sysdig's AWS account. This role is attached to the EventBridge target that is created in the source account.
#
# This role will be used by EventBridge when sending events to Sysdig's EventBridge Bus. The EventBridge service is
# given permission to assume this role.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "event_bus_invoke_remote_event_bus" {
  name = local.eb_resource_name
  tags = var.tags

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
        "AWS": "${local.trusted_identity}"
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
}

resource "aws_iam_role_policy" "event_bus_invoke_remote_event_bus_policy" {
  name = local.eb_resource_name
  role = aws_iam_role.event_bus_invoke_remote_event_bus.id
  policy = jsonencode({
    Statement = [
      {
        Sid = "CloudTrailEventsPut"
        Action = [
          "events:PutEvents",
        ]
        Effect = "Allow"
        Resource = [
          "${local.target_event_bus_arn}",
        ]
      },
      {
        Sid = "CloudTrailEventRuleAccess"
        Action = [
          "events:DescribeRule",
          "events:ListTargetsByRule",
        ]
        Effect = "Allow"
        Resource = [
          "${local.arn_prefix}:events:*:*:rule/${local.eb_resource_name}",
        ]
      },
    ]
  })
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

resource "aws_cloudformation_stack_set" "primary-acc-stackset" {
  # for single installs, primary account is the singleton account provided. for org installs, it is the mgmt account
  name                    = join("-", [local.eb_resource_name, "EBRulePrimaryAcc"])
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
    arn_prefix           = local.arn_prefix
    target_event_bus_arn = local.target_event_bus_arn
  })

  depends_on = [
    aws_iam_role.event_bus_invoke_remote_event_bus,
    aws_iam_role.event_bus_stackset_admin_role,
    aws_iam_role.event_bus_stackset_execution_role
  ]
}

// stackset instance to deploy rule in all regions of given account
resource "aws_cloudformation_stack_set_instance" "primary_acc_stackset_instance" {
  for_each       = local.region_set
  region         = each.key
  stack_set_name = aws_cloudformation_stack_set.primary-acc-stackset.name

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
  account_id = var.sysdig_secure_account_id
  type       = "COMPONENT_EVENT_BRIDGE"
  instance   = "secure-runtime"
  version    = "v0.1.0"
  event_bridge_metadata = jsonencode({
    aws = {
      role_name = local.eb_resource_name
      rule_name = local.eb_resource_name
      regions   = var.regions
    }
  })
}