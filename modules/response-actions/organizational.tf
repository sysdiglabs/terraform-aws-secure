#-----------------------------------------------------------------------------------------------------------------------
# These resources set up delegate IAM roles in member accounts of an AWS Organization for Response Actions via
# service-managed CloudFormation StackSets. For a single account installation, see main.tf.
#
# In an organizational deployment:
# 1. Lambda functions are created in the management account (main.tf) across all specified regions
# 2. Delegate roles are created in member accounts (this file) that allow Lambda functions to assume cross-account
#    access to perform response actions in those accounts
# 3. The delegate roles grant the Lambda execution roles permission to perform actions like quarantine users,
#    fetch logs, modify S3 buckets, and create snapshots in member accounts
#
# The delegate roles are deployed to all member accounts within the specified OUs, excluding the management account
# itself (since the Lambda execution roles already exist there).
#-----------------------------------------------------------------------------------------------------------------------

resource "aws_cloudformation_stack_set" "ra_delegate_roles" {
  count = var.is_organizational ? 1 : 0

  name = join("-", [local.ra_resource_name, "delegate-roles"])
  tags = merge(var.tags, {
    "sysdig.com/response-actions/resource-name" = "delegate-roles-stackset"
  })
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

  parameters = {
    TemplateVersion                      = md5(file("${path.module}/templates/delegate_roles_stackset.tpl"))
    QuarantineUserLambdaRoleArn          = local.enable_quarantine_user ? aws_iam_role.quarantine_user_role[0].arn : ""
    QuarantineUserRoleName               = local.enable_quarantine_user ? aws_iam_role.quarantine_user_role[0].name : ""
    FetchCloudLogsLambdaRoleArn          = local.enable_fetch_cloud_logs ? aws_iam_role.fetch_cloud_logs_role[0].arn : ""
    FetchCloudLogsRoleName               = local.enable_fetch_cloud_logs ? aws_iam_role.fetch_cloud_logs_role[0].name : ""
    RemovePolicyLambdaRoleArn            = local.enable_quarantine_user ? aws_iam_role.remove_policy_role[0].arn : ""
    RemovePolicyRoleName                 = local.enable_quarantine_user ? aws_iam_role.remove_policy_role[0].name : ""
    ConfigureResourceAccessLambdaRoleArn = local.enable_make_private ? aws_iam_role.configure_resource_access_role[0].arn : ""
    ConfigureResourceAccessRoleName      = local.enable_make_private ? aws_iam_role.configure_resource_access_role[0].name : ""
    CreateVolumeSnapshotsLambdaRoleArn   = local.enable_create_volume_snapshot ? aws_iam_role.create_volume_snapshots_role[0].arn : ""
    CreateVolumeSnapshotsRoleName        = local.enable_create_volume_snapshot ? aws_iam_role.create_volume_snapshots_role[0].name : ""
    DeleteVolumeSnapshotsLambdaRoleArn   = local.enable_create_volume_snapshot ? aws_iam_role.delete_volume_snapshots_role[0].arn : ""
    DeleteVolumeSnapshotsRoleName        = local.enable_create_volume_snapshot ? aws_iam_role.delete_volume_snapshots_role[0].name : ""
    EnableQuarantineUser                 = local.enable_quarantine_user ? "true" : "false"
    EnableFetchCloudLogs                 = local.enable_fetch_cloud_logs ? "true" : "false"
    EnableMakePrivate                    = local.enable_make_private ? "true" : "false"
    EnableCreateVolumeSnapshot           = local.enable_create_volume_snapshot ? "true" : "false"
  }

  template_body = file("${path.module}/templates/delegate_roles_stackset.tpl")

  depends_on = [
    aws_iam_role.quarantine_user_role,
    aws_iam_role.fetch_cloud_logs_role,
    aws_iam_role.remove_policy_role,
    aws_iam_role.configure_resource_access_role,
    aws_iam_role.create_volume_snapshots_role,
    aws_iam_role.delete_volume_snapshots_role
  ]
}

#-----------------------------------------------------------------------------------------------------------------------
# This resource deploys the delegate roles stackset to member accounts in the organization.
#
# Key deployment characteristics:
# - Deployed to organizational units specified in deployment_targets_org_units (from locals.tf)
# - Uses account_filter_type to exclude the management account (always excluded automatically in locals.tf)
# - Deployed to a single region per OU (delegate roles are global IAM resources)
# - Can optionally include/exclude specific accounts based on include_accounts/exclude_accounts variables
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_cloudformation_stack_set_instance" "ra_delegate_roles" {
  for_each = var.is_organizational ? {
    for ou in local.deployment_targets_org_units :
    ou => ou
  } : {}

  stack_set_instance_region = tolist(local.region_set)[0]
  stack_set_name            = aws_cloudformation_stack_set.ra_delegate_roles[0].name

  deployment_targets {
    organizational_unit_ids = [each.value]
    accounts                = local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy
    account_filter_type     = local.deployment_targets_accounts_filter
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
