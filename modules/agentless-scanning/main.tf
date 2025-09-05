##################################
# Controller IAM roles and stuff #
##################################

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

data "aws_iam_session_context" "current" {
  // Get the source role ARN from the currently assumed session role
  arn = data.aws_caller_identity.current.arn
}

data "sysdig_secure_agentless_scanning_assets" "assets" {}

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

#-----------------------------------------------------------------------------------------
# These locals indicate the provider account inormation and the region list passed.
#-----------------------------------------------------------------------------------------
locals {
  region_set = toset(var.regions)
  account_id = data.aws_caller_identity.current.account_id
  caller_arn = data.aws_iam_session_context.current.issuer_arn
}

#-----------------------------------------------------------------------------------------
# Generate a unique name for resources using random suffix
#-----------------------------------------------------------------------------------------
locals {
  scanning_resource_name = "${var.name}-${random_id.suffix.hex}"
}

#-----------------------------------------------------------------------------------------
# set StackSet roles
#-----------------------------------------------------------------------------------------
locals {
  administration_role_arn = var.auto_create_stackset_roles ? aws_iam_role.scanning_stackset_admin_role[0].arn : var.stackset_admin_role_arn
  execution_role_name     = var.auto_create_stackset_roles ? aws_iam_role.scanning_stackset_execution_role[0].name : var.stackset_execution_role_name
}

#-----------------------------------------------------------------------------------------------------------------------
# A random resource is used to generate unique name suffix for scanning resources.
# This prevents conflicts when recreating scanning resources with the same name.
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

resource "aws_iam_role" "scanning_stackset_admin_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "${local.scanning_resource_name}-AdministrationRole"
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

#-----------------------------------------------------------------------------------------------------------------------------------------
# Self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions.
#
# If auto_create_stackset_roles is true, terraform will create this IAM Admin role in the source account with permissions to create
# stacksets, Scanning resources and trust relationship to CloudFormation service. If false, and values for stackset Execution role
# name is provided stackset will use it, else AWS will look for predefined/default AWSCloudFormationStackSetExecutionRole.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "scanning_stackset_execution_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "${local.scanning_resource_name}-ExecutionRole"
  tags = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${aws_iam_role.scanning_stackset_admin_role[0].arn}"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachments_exclusive" "scanning_stackset_execution_role_managed_policy" {
  count     = !var.auto_create_stackset_roles ? 0 : 1
  role_name = aws_iam_role.scanning_stackset_execution_role[0].id
  policy_arns = [
    "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser",
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
  ]
}


#-----------------------------------------------------------------------------------------------------------------------------------------
# This resource creates a stackset and stackset instance to deploy resources for agentless scanning in the source account
#   - IAM Role
#   - KMS Key
#   - KMS Alias
#
# Note: self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_cloudformation_stack_set" "primary_acc_stackset" {
  name                    = join("-", [local.scanning_resource_name, "account"])
  tags                    = var.tags
  permission_model        = "SELF_MANAGED"
  capabilities            = ["CAPABILITY_NAMED_IAM"]
  administration_role_arn = local.administration_role_arn
  execution_role_name     = local.execution_role_name

  managed_execution {
    active = true
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  template_body = <<TEMPLATE
Resources:
  ScanningRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Join [ "-", [ "${local.scanning_resource_name}", !Ref AWS::Region ] ]
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
        - Effect: "Allow"
          Principal:
            AWS: ${data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity}
          Action: "sts:AssumeRole"
          Condition:
            StringEquals:
              sts:ExternalId: ${data.sysdig_secure_tenant_external_id.external_id.external_id}
      Policies:
      - PolicyName: ${local.scanning_resource_name}
        PolicyDocument:
          Version: "2012-10-17"
          Statement:
          - Sid: "Read"
            Effect: "Allow"
            Action:
            - "ec2:Describe*"
            Resource: "*"
            Condition:
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "AllowKMSKeysListing"
            Effect: "Allow"
            Action:
            - "kms:ListKeys"
            - "kms:ListAliases"
            - "kms:ListResourceTags"
            Resource: "*"
            Condition:
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "AllowKMSEncryptDecrypt"
            Effect: "Allow"
            Action:
            - "kms:DescribeKey"
            - "kms:Encrypt"
            - "kms:Decrypt"
            - "kms:ReEncrypt*"
            - "kms:GenerateDataKey*"
            - "kms:CreateGrant"
            Resource: "*"
            Condition:
              StringLike:
                "kms:ViaService": "ec2.*.amazonaws.com"
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "CreateTaggedSnapshotFromVolume"
            Effect: "Allow"
            Action:
            - "ec2:CreateSnapshot"
            Resource: "*"
            Condition:
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "CopySnapshots"
            Effect: "Allow"
            Action:
            - "ec2:CopySnapshot"
            Resource: "*"
            Condition:
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "SnapshotTags"
            Effect: "Allow"
            Action:
            - "ec2:CreateTags"
            Resource: "*"
            Condition:
              StringEquals:
                "ec2:CreateAction": ["CreateSnapshot", "CopySnapshot"]
                "aws:RequestTag/CreatedBy": "Sysdig"
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "ec2SnapshotShare"
            Effect: "Allow"
            Action:
            - "ec2:ModifySnapshotAttribute"
            Resource: "*"
            Condition:
              StringEqualsIgnoreCase:
                "aws:ResourceTag/CreatedBy": "Sysdig"
              StringEquals:
                "ec2:Add/userId": ${data.sysdig_secure_agentless_scanning_assets.assets.aws.account_id}
                "aws:RequestedRegion": !Ref AWS::Region
          - Sid: "ec2SnapshotDelete"
            Effect: "Allow"
            Action:
            - "ec2:DeleteSnapshot"
            Resource: "*"
            Condition:
              StringEqualsIgnoreCase:
                "aws:ResourceTag/CreatedBy": "Sysdig"
              StringEquals:
                "aws:RequestedRegion": !Ref AWS::Region
  AgentlessScanningKmsPrimaryKey:
    Type: AWS::KMS::Key
    Properties:
      Description: "Sysdig Agentless Scanning encryption key"
      PendingWindowInDays: ${var.kms_key_deletion_window}
      KeyUsage: "ENCRYPT_DECRYPT"
      EnableKeyRotation: true   # Enables automatic yearly rotation
      KeyPolicy:
        Id: ${local.scanning_resource_name}
        Statement:
        - Sid: "SysdigAllowKms"
          Effect: "Allow"
          Principal:
            AWS:
            - "arn:aws:iam::${data.sysdig_secure_agentless_scanning_assets.assets.aws.account_id}:root"
            - !GetAtt ScanningRole.Arn
          Action:
          - "kms:Encrypt"
          - "kms:Decrypt"
          - "kms:ReEncrypt*"
          - "kms:GenerateDataKey*"
          - "kms:DescribeKey"
          - "kms:CreateGrant"
          - "kms:ListGrants"
          Resource: "*"
        - Sid: "AllowCustomerManagement"
          Effect: "Allow"
          Principal:
            AWS:
            - "arn:aws:iam::${local.account_id}:root"
            - "${local.caller_arn}"
            - "arn:aws:iam::${local.account_id}:role/${local.execution_role_name}"
          Action: "kms:*"
          Resource: "*"
  AgentlessScanningKmsPrimaryAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: "alias/${local.scanning_resource_name}"
      TargetKeyId: !Ref AgentlessScanningKmsPrimaryKey

TEMPLATE

  depends_on = [
    aws_iam_role.scanning_stackset_admin_role,
    aws_iam_role.scanning_stackset_execution_role,
  ]
}

# stackset instance to deploy resources for agentless scanning, in all regions of given account
resource "aws_cloudformation_stack_set_instance" "primary_acc_stackset_instance" {
  for_each = local.region_set
  region   = each.key

  stack_set_name = aws_cloudformation_stack_set.primary_acc_stackset.name
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

#-----------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the trusted role for Agentless Scanning to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#-----------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_scanning_role" {
  account_id = var.sysdig_secure_account_id
  type       = "COMPONENT_TRUSTED_ROLE"
  instance   = "secure-scanning"
  version    = "v0.2.0"
  trusted_role_metadata = jsonencode({
    aws = {
      role_name = local.scanning_resource_name
    }
  })
}

#-----------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the KMS crypto key for Agentless Scanning to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#-----------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_crypto_key" {
  account_id = var.sysdig_secure_account_id
  type       = "COMPONENT_CRYPTO_KEY"
  instance   = "secure-scanning"
  version    = "v0.1.0"
  crypto_key_metadata = jsonencode({
    aws = {
      kms = {
        alias   = "alias/${local.scanning_resource_name}"
        regions = var.regions
      }
    }
  })
}
