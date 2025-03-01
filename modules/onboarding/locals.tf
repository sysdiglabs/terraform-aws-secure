#----------------------------------------------------------
# Fetch & compute required data for organizational install
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

# if both include and exclude accounts are provided, fetch all child accounts of final org_units_to_deploy to filter exclusions
data "aws_organizations_organizational_unit_descendant_accounts" "ou_children" {
  for_each  = local.deployment_targets.org_units_to_deploy
  parent_id = each.key
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
  ou_list = local.org_configuration == "excluded_ous_only" ? toset([for ou in data.aws_organizations_organizational_units.ou[0].children: ou.id]) : toset([])

  # switch cases for various user provided org configuration to be onboarded
  deployment_options = {
    entire_org = {
       org_units_to_deploy = local.root_org_units
    }
    included_ous_only = {
      org_units_to_deploy = var.include_ouids
    }
    excluded_ous_only = {
      # check if user provided excluded ouids are in ou_list to determine whether or not we can make exclusions, else we ignore and onboard entire org
      # TODO: update this if we find alternative to get all OUs in tree to filter exclusions for nested ouids as well
      org_units_to_deploy = length(setintersection(local.ou_list, var.exclude_ouids)) > 0 ? setsubtract(local.ou_list, var.exclude_ouids) : local.root_org_units
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
          var.is_organizational && length(var.include_accounts) > 0 && length(var.exclude_accounts) > 0 ? (
            "MIXED"
          ) : ""
        )
      )
    )
  )

  # handling exclusions when both include and exclude accounts are provided - fetch all accounts of every ou and filter exclusions
  org_accounts_list = local.accounts_configuration == "MIXED" ? flatten([ for ou_child_accounts in data.aws_organizations_organizational_unit_descendant_accounts.ou_children: [ ou_child_accounts.accounts[*].id ] ]) : []

  # switch cases for various user provided accounts configuration to be onboarded
  deployment_account_options = {
    NONE = {
      accounts_to_deploy = []
      account_filter_type = "NONE"
    }
    UNION = {
      accounts_to_deploy = var.include_accounts
      account_filter_type = "UNION"
    }
    DIFFERENCE = {
      accounts_to_deploy = var.exclude_accounts
      account_filter_type = "DIFFERENCE"
    }
    MIXED = {
      accounts_to_deploy = setunion(var.include_accounts, setsubtract(toset(local.org_accounts_list), var.exclude_accounts))
      account_filter_type = "UNION"
    }
    default = {
      accounts_to_deploy = []
      account_filter_type = "NONE"
    }
  }

  # list of accounts to deploy organizational resources in
  deployment_accounts = lookup(local.deployment_account_options, local.accounts_configuration, local.deployment_account_options.default)
}