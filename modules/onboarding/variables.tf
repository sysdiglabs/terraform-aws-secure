#---------------------------------
# optionals - with default
#---------------------------------

variable "is_organizational" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in an organizational setup (all accounts of org) or not (only on default aws provider account)"
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

variable "enable_automatic_onboarding" {
  type        = bool
  default     = false
  description = "true/false whether Sysdig should automatically discover latest set of accounts in onboarded organization or not"
}

variable "enable_aws_partner_tag" {
  type        = bool
  default     = true
  description = "Add the AWS Partner Revenue Measurement tag (aws-apn-id-900918371795 = pc:60xgt35ue7dm4pb1j44e9emhc) to the resources this module creates, so AWS can attribute their spend to Sysdig. The tag has no effect on how the resources work. Set to false to opt out, for example when tag policies reject unknown tags."
}
