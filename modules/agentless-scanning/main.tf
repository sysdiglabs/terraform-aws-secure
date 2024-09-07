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
# Generate a unique name for resources using random suffix and account ID hash
#-----------------------------------------------------------------------------------------
locals {
  account_id_hash        = substr(md5(local.account_id), 0, 4)
  scanning_resource_name = "${var.name}-${random_id.suffix.hex}-${local.account_id_hash}"
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

# IAM Policy Document used by Stackset roles for the KMS operations policy
data "aws_iam_policy_document" "kms_operations" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  statement {
    sid = "KmsOperationsAccess"
    effect = "Allow"
    actions = [
      "kms:*",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role" "scanning_stackset_admin_role" {
  count = !var.auto_create_stackset_roles ? 0 : 1

  name = "AWSCloudFormationStackSetAdministrationRoleForScanning"
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
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"]
  inline_policy {
    name   = "KmsOperationsAccess"
    policy = data.aws_iam_policy_document.kms_operations[0].json
  }
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

  name = "AWSCloudFormationStackSetExecutionRoleForScanning"
  tags = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${local.account_id}:role/${aws_iam_role.scanning_stackset_admin_role[0].name}"
      },
      "Effect": "Allow",
      "Condition": {}
    }
  ]
}
EOF
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  ]
  inline_policy {
    name   = "KmsOperationsAccess"
    policy = data.aws_iam_policy_document.kms_operations[0].json
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# These resources create a custom Agentless Scanning IAM Policy in the source account, referring a custom IAM Policy Document defining
# the respective permissions for scanning.
#-----------------------------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "scanning" {
  # General read permission, necessary for the discovery phase.
  statement {
    sid = "Read"

    actions = [
      "ec2:Describe*",
    ]

    resources = [
      "*",
    ]
  }

  # Allow the listing of KMS keys, necessary to find the right one.
  statement {
    sid = "AllowKMSKeysListing"

    actions = [
      "kms:ListKeys",
      "kms:ListAliases",
      "kms:ListResourceTags",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "AllowKMSEncryptDecrypt"

    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values = [
        "ec2.*.amazonaws.com",
      ]
    }
  }

  # Allows the creation of snapshots.
  statement {
    sid = "CreateTaggedSnapshotFromVolume"

    actions = [
      "ec2:CreateSnapshot",
    ]

    resources = [
      "*",
    ]
  }

  # Allows the copy of snapshot, which is necessary for re-encrypting
  # them to make them shareable with Sysdig account.
  statement {
    sid = "CopySnapshots"

    actions = [
      "ec2:CopySnapshot",
    ]

    resources = [
      "*",
    ]
  }

  # Allows tagging snapshots only for specific tag key and value.
  statement {
    sid = "SnapshotTags"

    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "*",
    ]

    # This condition limits the scope of tagging to the sole
    # CreateSnapshot and CopySnapshot operations.
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateSnapshot",
        "CopySnapshot",
      ]
    }

    # This condition limits the value of CreatedBy tag to the exact
    # string Sysdig.
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/CreatedBy"
      values   = ["Sysdig"]
    }
  }

  # This statement allows the modification of those snapshot that have
  # a simple "CreatedBy" tag valued "Sysdig". Additionally, such
  # snapshots can only be shared with a specific AWS account, namely
  # Sysdig account.
  statement {
    sid = "ec2SnapshotShare"

    actions = [
      "ec2:ModifySnapshotAttribute",
    ]

    condition {
      test     = "StringEqualsIgnoreCase"
      variable = "aws:ResourceTag/CreatedBy"
      values   = ["Sysdig"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:Add/userId"
      values = [
        data.sysdig_secure_agentless_scanning_assets.assets.aws.account_id
      ]
    }

    resources = [
      "*",
    ]
  }

  statement {
    sid = "ec2SnapshotDelete"

    actions = [
      "ec2:DeleteSnapshot",
    ]

    condition {
      test     = "StringEqualsIgnoreCase"
      variable = "aws:ResourceTag/CreatedBy"
      values   = ["Sysdig"]
    }

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "scanning_policy" {
  name        = local.scanning_resource_name
  description = "Grants Sysdig Secure access to volumes and snapshots"
  policy      = data.aws_iam_policy_document.scanning.json
  tags        = var.tags
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# These resources create an Assume Role IAM Policy Document, allowing Sysdig to assume role to run scanning.
#-----------------------------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "scanning_assume_role_policy" {
  statement {
    sid = "SysdigSecureScanning"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"
      identifiers = [
        data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.sysdig_secure_tenant_external_id.external_id.external_id]
    }
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# These resources create an Agentless Scanning IAM Role in the source account, with the Assume Role IAM Policy and
# custom Agentless Scanning IAM Policy attached.
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "scanning_role" {
  name               = local.scanning_resource_name
  tags               = var.tags
  assume_role_policy = data.aws_iam_policy_document.scanning_assume_role_policy.json
}

resource "aws_iam_policy_attachment" "scanning_policy_attachment" {
  name       = local.scanning_resource_name
  roles      = [aws_iam_role.scanning_role.name]
  policy_arn = aws_iam_policy.scanning_policy.arn
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# This resource creates a stackset and stackset instance to deploy resources for agentless scanning in the source account :-
#   - KMS Primary Key, and
#   - KMS Primary alias
#
# Note: self-managed stacksets require pair of StackSetAdministrationRole & StackSetExecutionRole IAM roles with self-managed permissions 
#-----------------------------------------------------------------------------------------------------------------------------------------

resource "aws_cloudformation_stack_set" "primary_acc_stackset" {
  name                    = join("-", [local.scanning_resource_name, "ScanningKmsPrimaryAcc"])
  tags                    = var.tags
  permission_model        = "SELF_MANAGED"
  capabilities            = ["CAPABILITY_NAMED_IAM"]
  administration_role_arn = var.auto_create_stackset_roles ? aws_iam_role.scanning_stackset_admin_role[0].arn : var.stackset_admin_role_arn
  execution_role_name     = var.auto_create_stackset_roles ? aws_iam_role.scanning_stackset_execution_role[0].name : var.stackset_execution_role_name

  managed_execution {
    active = true
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  template_body = <<TEMPLATE
Resources:
  AgentlessScanningKmsPrimaryKey:
      Type: AWS::KMS::Key
      Properties:
        Description: "Sysdig Agentless Scanning encryption key"
        PendingWindowInDays: ${var.kms_key_deletion_window}
        KeyUsage: "ENCRYPT_DECRYPT"
        KeyPolicy:
          Id: ${local.scanning_resource_name}
          Statement:
            - Sid: "SysdigAllowKms"
              Effect: "Allow"
              Principal:
                AWS: ["arn:aws:iam::${data.sysdig_secure_agentless_scanning_assets.assets.aws.account_id}:root", "arn:aws:iam::${local.account_id}:role/${local.scanning_resource_name}"]
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
                AWS: ["arn:aws:iam::${local.account_id}:root", "${local.caller_arn}"]
              Action: "kms:*"
              Resource: "*"
  AgentlessScanningKmsPrimaryAlias:
      Type: AWS::KMS::Alias
      Properties:
        AliasName: "alias/${local.scanning_resource_name}"
        TargetKeyId: !Ref AgentlessScanningKmsPrimaryKey

TEMPLATE

  depends_on = [
    aws_iam_role.scanning_role,
    aws_iam_role.scanning_stackset_admin_role,
    aws_iam_role.scanning_stackset_execution_role
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
  account_id                 = var.sysdig_secure_account_id
  type                       = "COMPONENT_TRUSTED_ROLE"
  instance                   = "secure-scanning"
  version                    = "v0.1.0"
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
  account_id                 = var.sysdig_secure_account_id
  type                       = "COMPONENT_CRYPTO_KEY"
  instance                   = "secure-scanning"
  version                    = "v0.1.0"
  crypto_key_metadata = jsonencode({
    aws = {
      kms = {
          alias   = "alias/${local.scanning_resource_name}"
          regions = var.regions
        }
    }
  })
}