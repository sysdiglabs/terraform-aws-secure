
#----------------------------------------------------------
# Since this is not an Organizational deploy, create role/polices directly
#----------------------------------------------------------
resource "aws_iam_role" "cspm_role" {
  count               = var.delegated_admin ? 0 : 1
  name                = var.role_name
  tags                = var.tags
  assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${var.trusted_identity}"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${var.external_id}"
                }
            }
        }
    ]
}
EOF
  managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
  inline_policy {
    name   = var.role_name
    policy = data.aws_iam_policy_document.custom_resources_policy.json
  }
}

# Custom IAM Policy Document used by trust-relationship role
data "aws_iam_policy_document" "custom_resources_policy" {

  statement {
    sid = "DescribeEFSAccessPoints"

    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeAccessPoints",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "ListWafRegionalRulesAndRuleGroups"

    effect = "Allow"

    actions = [
      "waf-regional:ListRules",
      "waf-regional:ListRuleGroups",
    ]

    resources = [
      "arn:aws:waf-regional:*:*:rule/*",
      "arn:aws:waf-regional:*:*:rulegroup/*"
    ]
  }

  statement {
    sid = "ListJobsOnConsole"

    effect = "Allow"

    actions = [
      "macie2:ListClassificationJobs",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "GetFunctionDetails"

    effect = "Allow"

    actions = [
      "lambda:GetRuntimeManagementConfig",
      "lambda:GetFunction",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "AccessAccountContactInfo"

    effect = "Allow"

    actions = [
      "account:GetContactInformation",
    ]

    resources = [
      "*",
    ]
  }
}

