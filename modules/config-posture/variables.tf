#---------------------------------
# optionals - with default
#---------------------------------

variable "is_organizational" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in an organizational setup (all accounts of org) or not (only on default aws provider account)"
}

variable "org_units" {
  description = <<-EOF
    TO BE DEPRECATED: Defaults to `[]`, use `include_ouids` instead.
    When set, org units to install cspm."
    EOF
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

variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Config Posture for (incase of organization, ID of the Sysdig management account)"
}

variable "is_gov_cloud_onboarding" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in a govcloud account/org or not"
}

variable "include_ouids" {
  description = "(Optional) ouids to include for organization"
  type        = set(string)
  default     = []
}

variable "exclude_ouids" {
  description = "(Optional) ouids to exclude for organization"
  type        = set(string)
  default     = []
}

variable "include_accounts" {
  description = "(Optional) accounts to include for organization"
  type        = set(string)
  default     = []
}

variable "exclude_accounts" {
  description = "(Optional) accounts to exclude for organization"
  type        = set(string)
  default     = []
}