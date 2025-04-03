#-----------------------------------------------------------------------------------------------------------------------
# Determine if this is an Organizational install, or a single account install. For Organizational installs, resources
# are created using CloudFormation StackSet. For Single Account installs see main.tf.
#-----------------------------------------------------------------------------------------------------------------------

locals {
  policy_document_no_lambda = <<TEMPLATE
Resources:
  SysdigAgentlessWorkloadRole:
      Type: AWS::IAM::Role
      Properties:
        RoleName: ${local.ecr_role_name}
        AssumeRolePolicyDocument:
          Version: "2012-10-17"
          Statement:
            - Sid: "SysdigSecureScanning"
              Effect: "Allow"
              Action: "sts:AssumeRole"
              Principal:
                AWS: "${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}"
              Condition:
                StringEquals:
                  sts:ExternalId: "${data.sysdig_secure_tenant_external_id.cloud_auth_external_id.external_id}"
        Policies:
          - PolicyName: ${local.ecr_role_name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Sid: "EcrReadPermissions"
                  Effect: "Allow"
                  Action:
                    - "ecr:GetDownloadUrlForLayer"
                    - "ecr:BatchGetImage"
                    - "ecr:BatchCheckLayerAvailability"
                    - "ecr:ListImages"
                    - "ecr:GetAuthorizationToken"
                  Resource: "*"

TEMPLATE
}

locals {
  policy_document_lambda = <<TEMPLATE
Resources:
  SysdigAgentlessWorkloadRole:
      Type: AWS::IAM::Role
      Properties:
        RoleName: ${local.ecr_role_name}
        AssumeRolePolicyDocument:
          Version: "2012-10-17"
          Statement:
            - Sid: "SysdigSecureScanning"
              Effect: "Allow"
              Action: "sts:AssumeRole"
              Principal:
                AWS: "${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}"
              Condition:
                StringEquals:
                  sts:ExternalId: "${data.sysdig_secure_tenant_external_id.cloud_auth_external_id.external_id}"
        Policies:
          - PolicyName: ${local.ecr_role_name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Sid: "EcrReadPermissions"
                  Effect: "Allow"
                  Action:
                    - "ecr:GetDownloadUrlForLayer"
                    - "ecr:BatchGetImage"
                    - "ecr:BatchCheckLayerAvailability"
                    - "ecr:ListImages"
                    - "ecr:GetAuthorizationToken"
                    - "lambda:GetFunction"
                    - "lambda:GetFunctionConfiguration"
                    - "lambda:GetRuntimeManagementConfig"
                    - "lambda:ListFunctions"
                    - "lambda:ListTagsForResource"
                    - "lambda:GetLayerVersionByArn"
                    - "lambda:GetLayerVersion"
                    - "lambda:ListLayers"
                    - "lambda:ListLayerVersions"
                  Resource: "*"
TEMPLATE
}

#-----------------------------------------------------------------------------------------------------------------------
# The resources in this file set up an Agentless Workload Scanning IAM Role and Policies in all accounts
# in an AWS Organization via a CloudFormation StackSet.
# Global resources: IAM Role and Policy
#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------
# stackset and stackset instance deployed in organization units for Agentless Scanning IAM Role, Policies
#-----------------------------------------------------------------------------------------------------------------------

# stackset to deploy agentless workload scanning role in organization unit
resource "aws_cloudformation_stack_set" "scanning_role_stackset" {
  count = var.is_organizational ? 1 : 0

  name             = join("-", [local.ecr_role_name, "ScanningRoleOrg"])
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

  template_body = var.lambda_scanning_enabled ? local.policy_document_lambda : local.policy_document_no_lambda
}

# stackset instance to deploy agentless scanning role, in all organization units
resource "aws_cloudformation_stack_set_instance" "scanning_role_stackset_instance" {
  count = var.is_organizational ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.scanning_role_stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.deployment_targets_org_units
    accounts                = local.check_old_ouid_param ? null : (local.deployment_targets_accounts_filter == "NONE" ? null : local.deployment_targets_accounts.accounts_to_deploy)
    account_filter_type     = local.check_old_ouid_param ? null : local.deployment_targets_accounts_filter
  }
  operation_preferences {
    max_concurrent_percentage    = 100
    failure_tolerance_percentage = var.failure_tolerance_percentage
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
    # Roles are not regional and hence do not need regional parallelism
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}
