#----------------------------------------------------------
# Fetch & compute required data for organizational install
#----------------------------------------------------------

data "aws_organizations_organization" "org" {
  count = var.is_organizational ? 1 : 0
}

locals {
  # fetch the AWS Root OU under org
  # As per https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html#organization-structure, there can be only one root
  root_org_unit = var.is_organizational ? [for root in data.aws_organizations_organization.org[0].roots : root.id] : []
}

# *****************************************************************************************************************************************************
# INCLUDE/EXCLUDE CONFIGURATION SUPPORT
#
# 1. Inclusions will always be handled for TF cloud provisioning.
#    NOTE:
#    Till AWS issue with UNION filter (https://github.com/aws-cloudformation/aws-cloudformation-resource-providers-cloudformation/issues/100)
#    is fixed, we can't deploy using UNION filters for inclusions. As a workaround to ensure we don't skip any accounts, we deploy it to entire org.
#
# 2. We handle exclusions when only exclusion parameters are provided i.e out of all 4 configuration inputs,
#      a. only exclude_ouids are provided, OR
#      b. only exclude_accounts are provided, OR
#      c. only exclude_ouids AND exclude_accounts are provided
#    Else we ignore exclusions during cloud resource provisioning through TF. This is because AWS does not allow both operations - to include some
#    accounts and to exclude some. Hence, we will always prioritize include over exclude.
#
# 3. Sysdig however will honor all combinations of configuration inputs exactly as desired.
# *****************************************************************************************************************************************************

#------------------------------------------------------------
# Manage configurations to determine OU targets to deploy in
#------------------------------------------------------------

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

  # switch cases for various user provided org configuration to be onboarded
  deployment_options = {
    entire_org = {
      org_units_to_deploy = local.root_org_unit
    }
    included_ous_only = {
      org_units_to_deploy = var.include_ouids
    }
    excluded_ous_only = {
      # onboard entire org and filter out all accounts in excluded OUs using account filter
      org_units_to_deploy = local.root_org_unit
    }
    mixed_ous = {
      # if both include and exclude ouids are provided, includes override excludes
      org_units_to_deploy = var.include_ouids
    }
    default = {
      org_units_to_deploy = local.root_org_unit
    }
  }

  # final targets to deploy organizational resources in
  deployment_targets_ous = lookup(local.deployment_options, local.org_configuration, local.deployment_options.default)

  exclude_root_ou = length(local.root_org_unit) > 0 ? contains(var.exclude_ouids, local.root_org_unit[0]) : false
}

#-----------------------------------------------------------------
# Manage configurations to determine account targets to deploy in
#-----------------------------------------------------------------

# if only exclude_ouids are provided and as long as it isn't Root OU, fetch all their child accounts to filter exclusions
data "aws_organizations_organizational_unit_descendant_accounts" "ou_accounts_to_exclude" {
  for_each  = local.org_configuration == "excluded_ous_only" && !local.exclude_root_ou ? var.exclude_ouids : []
  parent_id = each.key
}
locals {
  # ACCOUNTS CONFIGURATION (determine user provided accounts configuration)
  accounts_configuration = (
    # case1 - if only included accounts provided, include those accts as well
    var.is_organizational && length(var.include_accounts) > 0 && length(var.exclude_accounts) == 0 ? (
      "UNION"
      ) : (
      # case2 - if only excluded accounts or only excluded ouids provided, exclude those accounts
      var.is_organizational && length(var.include_accounts) == 0 && (length(var.exclude_accounts) > 0 || local.org_configuration == "excluded_ous_only") ? (
        "DIFFERENCE"
        ) : (
        # case3 - if both include and exclude accounts are provided, includes override excludes
        var.is_organizational && length(var.include_accounts) > 0 && length(var.exclude_accounts) > 0 ? (
          "MIXED"
        ) : ""
      )
    )
  )

  ou_accounts_to_exclude = flatten([for ou_accounts in data.aws_organizations_organizational_unit_descendant_accounts.ou_accounts_to_exclude : [ou_accounts.accounts[*].id]])
  accounts_to_exclude    = setunion(local.ou_accounts_to_exclude, var.exclude_accounts)

  # switch cases for various user provided accounts configuration to be onboarded
  deployment_account_options = {
    UNION = {
      accounts_to_deploy  = var.include_accounts
      account_filter_type = "UNION"
    }
    DIFFERENCE = {
      accounts_to_deploy  = local.accounts_to_exclude
      account_filter_type = "DIFFERENCE"
    }
    MIXED = {
      accounts_to_deploy  = var.include_accounts
      account_filter_type = "UNION"
    }
    default = {
      # default when neither of include/exclude accounts are provided
      accounts_to_deploy  = []
      account_filter_type = "NONE"
    }
  }

  # list of accounts to deploy organizational resources in
  deployment_targets_accounts = lookup(local.deployment_account_options, local.accounts_configuration, local.deployment_account_options.default)
}

# -----------------------------------------------------------------------------------------------------
# Remove below conditional once AWS issue is fixed -
# https://github.com/aws-cloudformation/aws-cloudformation-resource-providers-cloudformation/issues/100
# -----------------------------------------------------------------------------------------------------
locals {
  # XXX: due to AWS bug of not having UNION filter fully working, there is no way to add those extra accounts requested.
  # to not miss out on those extra accounts, deploy the cloud resources across entire org and noop the UNION filter.
  # i.e till we can't deploy UNION, we deploy it all
  deployment_targets_org_units       = local.deployment_targets_accounts.account_filter_type == "UNION" ? local.root_org_unit : local.deployment_targets_ous.org_units_to_deploy
  deployment_targets_accounts_filter = local.deployment_targets_accounts.account_filter_type == "UNION" ? "NONE" : local.deployment_targets_accounts.account_filter_type
}
