variable "tags" {
  type        = map(string)
  description = "sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning"
  default = {
    "product" = "sysdig-secure-for-cloud"
  }
}

variable "is_organizational" {
  description = "(Optional) Set this field to 'true' to deploy Agentless Workload Scanning to an AWS Organization (Or specific OUs)"
  type        = bool
  default     = false
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

variable "lambda_scanning_enabled" {
  type        = bool
  description = "Set this field to 'true' to deploy Agentless Workload Scanning for Lambda functions"
  default     = false
}


variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Config Posture for (incase of organization, ID of the Sysdig management account)"
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

variable "enable_aws_partner_tag" {
  type        = bool
  default     = true
  description = "Add the AWS Partner Revenue Measurement tag (aws-apn-id-900918371795 = pc:60xgt35ue7dm4pb1j44e9emhc) to the resources this module creates, so AWS can attribute their spend to Sysdig. The tag has no effect on how the resources work. Set to false to opt out, for example when tag policies reject unknown tags."
}
