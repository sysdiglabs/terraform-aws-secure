output "cross_account_role_arn" {
  description = "ARN of the cross-account role for Lambda invocation"
  value       = aws_iam_role.shared_cross_account_lambda_invoker.arn
}

output "lambda_functions" {
  description = "Information about deployed Lambda functions"
  value = {
    quarantine_user = {
      name = module.quarantine_user_function.function_name
      arn  = module.quarantine_user_function.function_arn
    }
    remove_policy = {
      name = module.remove_policy_function.function_name
      arn  = module.remove_policy_function.function_arn
    }
    fetch_cloud_logs = {
      name = module.fetch_cloud_logs_function.function_name
      arn  = module.fetch_cloud_logs_function.function_arn
    }
    create_volume_snapshots = {
      name = module.create_volume_snapshots_function.function_name
      arn = module.create_volume_snapshots_function.function_arn
    }
  }
}
