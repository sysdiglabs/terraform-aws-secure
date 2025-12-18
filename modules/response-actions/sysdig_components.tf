#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the response actions responder integration to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_responder" {
  account_id = var.sysdig_secure_account_id
  type       = local.responder_component_type
  instance   = "cloud-responder"
  version    = "v${var.response_actions_version}"
  cloud_responder_metadata = jsonencode({
    aws = {
      responder_lambdas = {
        lambda_names       = local.enabled_lambda_names
        regions            = local.region_set
        delegate_role_name = aws_iam_role.shared_cross_account_lambda_invoker.name
      }
    }
  })

  depends_on = [
    aws_cloudformation_stack_set_instance.lambda_functions,
    aws_iam_role.shared_cross_account_lambda_invoker
  ]
}

resource "sysdig_secure_cloud_auth_account_component" "aws_responder_roles" {
  account_id = var.sysdig_secure_account_id
  type       = local.roles_component_type
  instance   = "cloud-responder"
  version    = "v${var.response_actions_version}"
  cloud_responder_roles_metadata = jsonencode({
    roles = concat(
      local.enable_quarantine_user ? [
        {
          aws = {
            role_name = aws_iam_role.quarantine_user_role[0].arn
          }
        },
        {
          aws = {
            role_name = aws_iam_role.remove_policy_role[0].arn
          }
        }
      ] : [],
      local.enable_fetch_cloud_logs ? [
        {
          aws = {
            role_name = aws_iam_role.fetch_cloud_logs_role[0].arn
          }
        }
      ] : [],
      local.enable_make_private ? [
        {
          aws = {
            role_name = aws_iam_role.configure_resource_access_role[0].arn
          }
        }
      ] : [],
      local.enable_create_volume_snapshot ? [
        {
          aws = {
            role_name = aws_iam_role.create_volume_snapshots_role[0].arn
          }
        },
        {
          aws = {
            role_name = aws_iam_role.delete_volume_snapshots_role[0].arn
          }
        }
      ] : []
    )
  })

  depends_on = [
    aws_cloudformation_stack_set_instance.lambda_functions,
    aws_iam_role.quarantine_user_role,
    aws_iam_role.remove_policy_role,
    aws_iam_role.fetch_cloud_logs_role,
    aws_iam_role.configure_resource_access_role,
    aws_iam_role.create_volume_snapshots_role,
    aws_iam_role.delete_volume_snapshots_role
  ]
}
