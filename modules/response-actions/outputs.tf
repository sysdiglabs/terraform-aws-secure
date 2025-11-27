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
  value = {
    quarantine_user = {
      name = "${local.ra_resource_name}-quarantine-user"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-quarantine-user"]
    }
    fetch_cloud_logs = {
      name = "${local.ra_resource_name}-fetch-cloud-logs"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-fetch-cloud-logs"]
    }
    remove_policy = {
      name = "${local.ra_resource_name}-remove-policy"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-remove-policy"]
    }
    configure_resource_access = {
      name = "${local.ra_resource_name}-configure-resource-access"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-configure-resource-access"]
    }
    create_volume_snapshots = {
      name = "${local.ra_resource_name}-create-volume-snapshots"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-create-volume-snapshots"]
    }
    delete_volume_snapshots = {
      name = "${local.ra_resource_name}-delete-volume-snapshots"
      arns = [for region in local.region_set : "${local.arn_prefix}:lambda:${region}:${data.aws_caller_identity.current.account_id}:function:${local.ra_resource_name}-delete-volume-snapshots"]
    }
  }
}
