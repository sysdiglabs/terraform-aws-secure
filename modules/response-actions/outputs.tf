output "cross_account_role_arn" {
  description = "ARN of the cross-account role for Lambda invocation"
  value       = aws_iam_role.shared_cross_account_lambda_invoker.arn
}

output "stackset_name" {
  description = "Name of the CloudFormation StackSet deploying Lambda functions"
  value       = aws_cloudformation_stack_set.lambda_functions.name
}

output "stackset_id" {
  description = "ID of the CloudFormation StackSet"
  value       = aws_cloudformation_stack_set.lambda_functions.id
}

output "deployment_regions" {
  description = "List of regions where Lambda functions are deployed"
  value       = local.region_set
}

output "lambda_functions" {
  description = "Information about deployed Lambda functions across all regions"
  value = merge(
    local.enable_quarantine_user ? {
      quarantine_user = {
        name = "${local.ra_resource_name}-quarantine-user"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-quarantine-user"]
      }
      remove_policy = {
        name = "${local.ra_resource_name}-remove-policy"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-remove-policy"]
      }
    } : {},
    local.enable_fetch_cloud_logs ? {
      fetch_cloud_logs = {
        name = "${local.ra_resource_name}-fetch-cloud-logs"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-fetch-cloud-logs"]
      }
    } : {},
    local.enable_make_private ? {
      configure_resource_access = {
        name = "${local.ra_resource_name}-configure-resource-access"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-configure-resource-access"]
      }
    } : {},
    local.enable_create_volume_snapshot ? {
      create_volume_snapshots = {
        name = "${local.ra_resource_name}-create-volume-snapshots"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-create-volume-snapshots"]
      }
      delete_volume_snapshots = {
        name = "${local.ra_resource_name}-delete-volume-snapshots"
        arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-delete-volume-snapshots"]
      }
    } : {}
  )
}

output "responder_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_responder.type}/${sysdig_secure_cloud_auth_account_component.aws_responder.instance}"
  description = "Component identifier of Response Actions responder integration created in Sysdig Backend"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_responder]
}

output "responder_roles_component_id" {
  value       = "${sysdig_secure_cloud_auth_account_component.aws_responder_roles.type}/${sysdig_secure_cloud_auth_account_component.aws_responder_roles.instance}"
  description = "Component identifier of Response Actions roles integration created in Sysdig Backend"
  depends_on  = [sysdig_secure_cloud_auth_account_component.aws_responder_roles]
}

output "wait_after_basic" {
  value       = var.wait_after_basic_seconds > 0 ? time_sleep.wait_after_ciem_basic : null
  description = "Wait handle to delay downstream operations after basic by the configured seconds."
}
