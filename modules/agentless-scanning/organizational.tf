#-----------------------------------------------------------------------------------------------------------------------
# The resources in this file set up an Agentless Scanning IAM Role, Policies, KMS keys and KMS Aliases in all accounts
# in an AWS Organization via service-managed CloudFormation StackSets. For a single account installation, see main.tf.
# Global resources: IAM Role and Policy
# Non-global / Regional resources:
# - a KMS Primary key is created, in each region of region list,
# - an Alias by the same name for the respective key, in each region of region list.
#-----------------------------------------------------------------------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  root_org_id = [for root in data.aws_organizations_organization.org[0].roots : root.id]
  organizational_unit_ids = var.is_organizational && length(var.org_units) == 0 ? (length(var.org_accounts) == "0" ? local.root_org_id : []) : toset(var.org_units)
  account_ids = var.is_organizational && length(var.org_accounts) == 0 ? [] : setunion(toset(var.org_accounts),[data.aws_caller_identity.current.account_id])
}

#-----------------------------------------------------------------------------------------------------------------------
# stackset and stackset instance deployed for all accounts in all organization units
#   - IAM Role
#   - KMS Primary Key
#   - KMS Primary alias
#-----------------------------------------------------------------------------------------------------------------------

# stackset to deploy resources for agentless scanning in organization unit
resource "aws_cloudformation_stack_set" "ou_resources_stackset" {
  count = var.is_organizational ? 1 : 0

  name             = join("-", [local.scanning_resource_name, "organization"])
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
    ignore_changes = [administration_role_arn] # https://github.com/hashicorp/terraform-provider-aws/issues/23464
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
            - !Sub "arn:aws:iam::$${AWS::AccountId}:root"
            - "${local.caller_arn}"
            - !Sub "arn:aws:iam::$${AWS::AccountId}:role/aws-service-role/member.org.stacksets.cloudformation.amazonaws.com/AWSServiceRoleForCloudFormationStackSetsOrgMember"
          Action:
          - "kms:*"
          Resource: "*"
  AgentlessScanningKmsPrimaryAlias:
      Type: AWS::KMS::Alias
      Properties:
        AliasName: "alias/${local.scanning_resource_name}"
        TargetKeyId: !Ref AgentlessScanningKmsPrimaryKey

TEMPLATE
}

# stackset instance to deploy resources for agentless scanning, in all regions of each account in all organization units
resource "aws_cloudformation_stack_set_instance" "ou_stackset_instance" {
  for_each   = var.is_organizational ? (length(local.organizational_unit_ids) > 0 ? local.region_set : toset([])) : toset([])
  region     = each.key

  stack_set_name = aws_cloudformation_stack_set.ou_resources_stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.organizational_unit_ids
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

resource "aws_cloudformation_stack_set_instance" "accounts_stackset_instance" {
  for_each   = var.is_organizational ? (length(local.account_ids) > 0 ? local.region_set : toset([])) : toset([])
  region     = each.key

  stack_set_name = aws_cloudformation_stack_set.ou_resources_stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.root_org_id
    accounts = local.account_ids
    account_filter_type = "INTERSECTION"
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