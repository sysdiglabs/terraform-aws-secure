data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  organizational_unit_ids = var.is_organizational && length(var.org_units) == 0 ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : toset(var.org_units)
}

resource "aws_cloudformation_stack_set" "eb_rule_api_dest_stackset" {
  count = var.is_organizational ? 1 : 0

  name             = join("-", [local.eb_resource_name, "ApiDestAndRule"])
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

  template_body = templatefile("${path.module}/stackset_template_eb_rule_api_dest.tpl", {
    name          = local.eb_resource_name
    api_key       = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_api_key
    endpoint_url  = data.sysdig_secure_cloud_ingestion_assets.assets.aws.eb_routing_url
    rate_limit    = var.api_dest_rate_limit
    event_pattern = jsonencode(var.event_pattern)
    rule_state    = var.rule_state
    arn_prefix    = local.arn_prefix
  })
}

resource "aws_cloudformation_stack_set" "eb_role_stackset" {
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

  template_body = templatefile("${path.module}/stackset_template_org_policies.tpl", {
    name            = local.eb_resource_name
    trusted_identity = local.trusted_identity
    external_id     = data.sysdig_secure_tenant_external_id.external_id.external_id
    arn_prefix      = local.arn_prefix
  })
}

resource "aws_cloudformation_stack_set_instance" "eb_rule_api_dest_instance" {
  for_each = var.is_organizational ? local.region_set : toset([])
  region   = each.key

  stack_set_name = aws_cloudformation_stack_set.eb_rule_api_dest_stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.deployment_targets_org_units
    accounts                = local.check_old_ouid_param ? null : (local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy)
    account_filter_type     = local.check_old_ouid_param ? null : local.deployment_targets_accounts_filter
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

resource "aws_cloudformation_stack_set_instance" "eb_role_stackset_instance" {
  count = var.is_organizational ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.eb_role_stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.deployment_targets_org_units
    accounts                = local.check_old_ouid_param ? null : (local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy)
    account_filter_type     = local.check_old_ouid_param ? null : local.deployment_targets_accounts_filter
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}
