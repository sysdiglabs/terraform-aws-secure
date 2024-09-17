#-----------------------------------------------------------------------------------------------------------------------
# The only resource needed to make Sysdig's backend start to fetch data from the CloudTrail associated s3 bucket is a
# properly set AWS IAM Role. Sysdig's trusted identity act as the Principal in the assume role Policy, namely the role
# that the backend will use to assume the Client's role. At that point, given the permission set granted to the newly
# created Role in the Client's account, Sysdig's backend will be able to perform all the required actions in order to
# retrieve the log files that are automatically published in the target s3 bucket.
#
# Note: this setup assumes that the Customer has already properly set up an AWS CloudTrail Trail and the associated bucket.
# Sysdig's Secure UI provides the necessary information to make the Customer perform the
# required setup operations before applying the Terraform module.
#-----------------------------------------------------------------------------------------------------------------------

data "sysdig_secure_trusted_cloud_identity" "trusted_identity" {
  cloud_provider = "aws"
}

data "sysdig_secure_tenant_external_id" "external_id" {}

# AWS IAM Role that will be used by CloudIngestion to access the CloudTrail-associated s3 bucket
resource "aws_iam_role" "cloudlogs_s3_access" {
  name = var.role_name
  tags = var.tags

  assume_role_policy = data.aws_iam_policy_document.assume_cloudlogs_s3_access_role.json
  inline_policy {
    name   = "cloudlogs_s3_access_policy"
    policy = data.aws_iam_policy_document.cloudlogs_s3_access.json
  }
}

# IAM Policy Document used for the assume role policy
data "aws_iam_policy_document" "assume_cloudlogs_s3_access_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
        identifiers = [data.sysdig_secure_trusted_cloud_identity.trusted_identity.identity]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.sysdig_secure_tenant_external_id.external_id.external_id]
    }
  }
}

# IAM Policy Document used for the bucket access policy
data "aws_iam_policy_document" "cloudlogs_s3_access" {
  statement {
    sid = "CloudlogsS3AccessGet"

    effect = "Allow"

    actions = [
      "s3:Get*",
    ]

    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*"
    ]
  }

  statement {
    sid = "CloudlogsS3AccessList"

    effect = "Allow"

    actions = [
      "s3:List*"
    ]

    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*"
    ]
  }
}

#-----------------------------------------------------------------------------------------------------------------------------------------
# Call Sysdig Backend to add the event-bridge integration to the Sysdig Cloud Account
#
# Note (optional): To ensure this gets called after all cloud resources are created, add
# explicit dependency using depends_on
#-----------------------------------------------------------------------------------------------------------------------------------------
resource "sysdig_secure_cloud_auth_account_component" "aws_cloud_logs" {
  account_id                 = var.sysdig_secure_account_id
  type                       = "COMPONENT_CLOUD_LOGS"
  instance                   = "secure-runtime"
  version                    = "v0.1.0"
  cloud_logs_metadata = jsonencode({
    aws = {
      cloudtrailS3Bucket = {
        folder_arn    = var.folder_arn
        role_name     = var.role_name
        external_id   = data.sysdig_secure_tenant_external_id.external_id.external_id
        region        = var.region
      }
    }
  })
}
