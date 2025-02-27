#----------------------------------------------------------
# Fetch & compute required data
#----------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  # fetch the AWS Root OU
  root_org_units = var.is_organizational ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : []
}

# if only excluded ouids provided, fetch children ous in org to filter exclusions
# note: AWS fetches only first level immediate children, since it has no data source to give all OUs recursively
data "aws_organizations_organizational_units" "ou" {
  count     = var.is_organizational && length(var.include_ouids) == 0 && length(var.exclude_ouids) > 0 ? 1 : 0
  parent_id = data.aws_organizations_organization.org[0].roots[0].id
}

#----------------------------------------------------------
# Manage configurations to determine targets to deploy in
#----------------------------------------------------------

locals {
  # OU CONFIGURATION (determine user provided org configuration)
  org_configuration = (
    # case1 - if no include/exclude ous provided, include entire org
    var.is_organizational && length(var.include_ouids) == 0 && length(var.exclude_ouids) == 0 ? (
      "entire_org"
    ) : (
      # case2 - if only included ouids provided, include those ous only
      var.is_organizational && length(var.include_ouids) > 0 && length(var.exclude_ouids) == 0 ? (
        "included_ous_only"
      ) : (
        # case3 - if only excluded ouids provided, exclude their accounts from rest of org
        var.is_organizational && length(var.include_ouids) == 0 && length(var.exclude_ouids) > 0 ? (
          "excluded_ous_only"
        ) : (
          # case4 - if both include and exclude ouids are provided, includes override excludes
          var.is_organizational && length(var.include_ouids) > 0 && length(var.exclude_ouids) > 0 ? (
            "mixed_ous"
          ) : ""
        )
      )
    )
  )

  # handling exclusions when only excluded ouids are provided
  # fetch list of all ouids to filter exclusions (AWS data source only returns first level immediate children)
  oulist = local.org_configuration == "excluded_ous_only" ? toset([for ou in data.aws_organizations_organizational_units.ou[0].children: ou.id]) : toset([])

  # switch cases for various user provided org configuration to be onboarded
  deployment_options = {
    entire_org = {
       org_units_to_deploy = local.root_org_units
    }
    included_ous_only = {
      org_units_to_deploy = var.include_ouids
    }
    excluded_ous_only = {
      # check if user provided excluded ouids are in oulist to determine whether or not we can make exclusions, else we ignore and onboard entire org
      # TODO: update this if we find alternative to get all OUs in tree to filter exclusions for nested ouids as well
      org_units_to_deploy = length(setintersection(local.oulist, var.exclude_ouids)) > 0 ? setsubtract(local.oulist, var.exclude_ouids) : local.root_org_units
    }
    mixed_ous = {
      # if both include and exclude ouids are provided, includes override excludes
      org_units_to_deploy = var.include_ouids
    }
    default = {
      org_units_to_deploy = []
    }
  }

  # final targets to deploy organizational resources in
  deployment_targets = lookup(local.deployment_options, local.org_configuration, local.deployment_options.default)
}

locals {
  # ACCOUNTS CONFIGURATION (determine user provided accounts configuration)
  accounts_configuration = (
    # case1 - if no include/exclude accounts provided
    var.is_organizational && length(var.include_accounts) == 0 && length(var.exclude_accounts) == 0 ? (
      "NONE"
    ) : (
      # case2 - if only included accounts provided, include those accts as well
      var.is_organizational && length(var.include_accounts) > 0 && length(var.exclude_accounts) == 0 ? (
        "UNION"
      ) : (
        # case3 - if only excluded accounts provided, exclude those accounts
        var.is_organizational && length(var.include_accounts) == 0 && length(var.exclude_accounts) > 0 ? (
          "DIFFERENCE"
        ) : (
          # case4 - if both include and exclude accounts are provided, includes override excludes
          # TODO: update this mixed case if we find an alternative to pass both inclusion & exclusion of accounts
          var.is_organizational && length(var.include_accounts) > 0 && length(var.exclude_accounts) > 0 ? (
            "UNION"
          ) : ""
        )
      )
    )
  )

  # switch cases for various user provided accounts configuration to be onboarded
  deployment_account_options = {
    NONE = {
      accounts_to_deploy = []
    }
    UNION = {
      accounts_to_deploy = var.include_accounts
    }
    DIFFERENCE = {
      accounts_to_deploy = var.exclude_accounts
    }
    default = {
      accounts_to_deploy = []
    }
  }

  # list of accounts to deploy organizational resources in
  deployment_accounts = lookup(local.deployment_account_options, local.accounts_configuration, local.deployment_account_options.default)
}

#----------------------------------------------------------
# Since this is an Organizational deploy, use a CloudFormation StackSet
#----------------------------------------------------------

resource "aws_cloudformation_stack_set" "stackset" {
  count = var.is_organizational ? 1 : 0

  name             = local.onboarding_role_name
  tags             = var.tags
  permission_model = "SERVICE_MANAGED"
  capabilities = ["CAPABILITY_NAMED_IAM"]

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

  template_body = <<TEMPLATE
Resources:
  SysdigOnboardingRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ${local.onboarding_role_name}
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              AWS: [ ${local.trusted_identity} ]
            Action: [ 'sts:AssumeRole' ]
            Condition:
              StringEquals:
                sts:ExternalId: ${data.sysdig_secure_tenant_external_id.external_id.external_id}
      Policies:
          - PolicyName: ${local.onboarding_role_name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Effect: Allow
                  Action:
                    - "account:Get*"
                    - "account:List*"
                  Resource: "*"
      ManagedPolicyArns:
        - "${local.arn_prefix}:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
TEMPLATE
}

resource "aws_cloudformation_stack_set_instance" "stackset_instance" {
  count = var.is_organizational ? 1 : 0

  region         = var.region == "" ? null : var.region
  stack_set_name = aws_cloudformation_stack_set.stackset[0].name
  deployment_targets {
    organizational_unit_ids = local.deployment_targets.org_units_to_deploy
    accounts                = local.accounts_configuration == "NONE" ? null : local.deployment_accounts.accounts_to_deploy
    account_filter_type     = local.accounts_configuration
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

resource "sysdig_secure_organization" "aws_organization" {
  count                          = var.is_organizational ? 1 : 0
  management_account_id          = sysdig_secure_cloud_auth_account.cloud_auth_account.id
  # TODO: once BE change is added
  # root_organizational_unit       = local.root_org_units[0]
  included_organizational_groups = var.include_ouids
  excluded_organizational_groups = var.exclude_ouids
  included_cloud_accounts        = var.include_accounts
  excluded_cloud_accounts        = var.exclude_accounts
}
