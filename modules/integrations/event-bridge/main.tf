data "aws_caller_identity" "current" {}

data "sysdig_secure_cloud_ingestion_assets" "assets" {
  cloud_provider     = "aws"
  cloud_provider_id  = data.aws_caller_identity.current.account_id
  component_type = local.component_type
}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

locals {
  region_set           = toset(var.regions)
  trusted_identity     = var.is_gov_cloud_onboarding ? data.sysdig_secure_trusted_cloud_identity.trusted_identity.gov_identity : data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity
  arn_prefix           = var.is_gov_cloud_onboarding ? "arn:aws-us-gov" : "arn:aws"
  component_type       = "COMPONENT_WEBHOOK_DATASOURCE"
}

locals {
  account_id_hash  = substr(md5(data.aws_caller_identity.current.account_id), 0, 4)
  eb_resource_name = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_iam_role" "event_bus_stackset_admin_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "AWSCloudFormationStackSetAdministrationRoleForEBApiDest"
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

resource "aws_iam_role" "event_bus_stackset_execution_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "AWSCloudFormationStackSetExecutionRoleForEBApiDest"
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

resource "aws_iam_role" "event_bridge_api_destination_role" {
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

resource "aws_iam_role_policy" "event_bridge_api_destination_policy" {
  name = local.eb_resource_name
  role = aws_iam_role.event_bridge_api_destination_role.id
  policy = jsonencode({
    Statement = [
      {
        Sid = "InvokeApiDestination"
        Action = [
          "events:InvokeApiDestination",
        ]
        Effect = "Allow"
        Resource = [
          "${local.arn_prefix}:events:*:*:api-destination/${local.eb_resource_name}-destination/*",
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
      {
        Sid = "ValidationAccess"
        Action = [
          "events:DescribeApiDestination",
          "events:DescribeConnection"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudformation_stack_set" "eb_rule_and_api_dest_stackset" {
  name                    = join("-", [local.eb_resource_name, "EBRuleAndApiDestination"])
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

  template_body = templatefile("${path.module}/stackset_template_eb_rule_api_dest.tpl", {
    name          = local.eb_resource_name
    api_key       = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_api_key
    endpoint_url  = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_routing_url
    rate_limit    = var.api_dest_rate_limit
    event_pattern = jsonencode(var.event_pattern)
    rule_state    = var.rule_state
    arn_prefix    = local.arn_prefix
  })

  depends_on = [
    aws_iam_role.event_bridge_api_destination_role,
    aws_iam_role.event_bus_stackset_admin_role,
    aws_iam_role.event_bus_stackset_execution_role
  ]
}

resource "aws_cloudformation_stack_set_instance" "eb_rule_and_api_dest_stackset_instance" {
  for_each       = local.region_set
  region         = each.key
  stack_set_name = aws_cloudformation_stack_set.eb_rule_and_api_dest_stackset.name

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

resource "sysdig_secure_cloud_auth_account_component" "aws_event_bridge" {
  account_id = var.sysdig_secure_account_id
  type       = local.component_type
  instance   = "secure-runtime"
  version    = "v0.1.0"
  webhook_datasource_metadata = jsonencode({
    aws = {
      webhook_datasource = {
        routing_key         = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_routing_key
        ingestion_url       = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_routing_url
        ingested_regions    = var.regions
        rule_name           = local.eb_resource_name
        api_dest_name       = "${local.eb_resource_name}-destination"
        api_dest_rate_limit = tostring(var.api_dest_rate_limit)
        role_name           = local.eb_resource_name
        connection_name     = "${local.eb_resource_name}-connection"
      }
    }
  })
}