#---------------------------------
# optionals - with default
#---------------------------------

variable "is_organizational" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in an organizational setup (all accounts of org) or not (only on default aws provider account)"
}

variable "organizational_unit_ids" {
  description = "restrict onboarding to a set of organizational unit identifiers whose child accounts and organizational units are to be onboarded. Default: onboard all organizational units"
  type        = set(string)
  default     = []
}

variable "region" {
  type        = string
  default     = ""
  description = "Default region for resource creation in organization mode"
}

variable "tags" {
  type        = map(string)
  description = "sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning"

  default = {
    "product" = "sysdig-secure-for-cloud"
  }
}

variable "timeout" {
  type        = string
  description = "Default timeout values for create, update, and delete operations"
  default     = "30m"
}

variable "failure_tolerance_percentage" {
  type        = number
  description = "The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region"
  default     = 90
}

variable "account_alias" {
  type        = string
  description = "Account Alias"
  default     = ""
}

variable "is_gov_cloud_onboarding" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in a govcloud account/org or not"
}

variable "organization_accounts_to_exclude" {
  type        = list(string)
  default     = []
  description = "AWS account IDs to exclude from organizational deployment"
}
