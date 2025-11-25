variable "is_organizational" {
  description = "(Optional) Set this field to 'true' to deploy EventBridge to an AWS Organization (Or specific OUs)"
  type        = bool
  default     = false
}

variable "org_units" {
  description = <<-EOF
    TO BE DEPRECATED on 30th November, 2025: Please work with Sysdig to migrate to using `include_ouids` instead.
    When set, list of Organization Unit IDs in which to setup EventBridge. By default, EventBridge will be setup in all accounts within the Organization.
    This field is ignored if `is_organizational = false`
    EOF
  type        = set(string)
  default     = []
}

variable "regions" {
  description = "(Optional) List of regions in which to setup EventBridge. By default, current region is selected"
  type        = set(string)
  default     = []
}

variable "name" {
  description = "(Optional) Name to be assigned to all child resources. A suffix may be added internally when required. Use default value unless you need to install multiple instances"
  type        = string
  default     = "sysdig-secure-events"
}

variable "tags" {
  description = "(Optional) Tags to be attached to all Sysdig resources."
  type        = map(string)
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

variable "auto_create_stackset_roles" {
  description = "Whether to auto create the custom stackset roles to run SELF_MANAGED stackset. Default is true"
  type        = bool
  default     = true
}

variable "stackset_admin_role_arn" {
  description = "(Optional) stackset admin role arn to run SELF_MANAGED stackset"
  type        = string
  default     = ""
}

variable "stackset_execution_role_name" {
  description = "(Optional) stackset execution role name to run SELF_MANAGED stackset"
  type        = string
  default     = ""
}

variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Event Bridge integration for (incase of organization, ID of the Sysdig management account)"
}

variable "is_gov_cloud_onboarding" {
  type        = bool
  default     = false
  description = "true/false whether EventBridge should be deployed in a govcloud account/org or not"
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

variable "api_dest_rate_limit" {
  type        = number
  default     = 300
  description = "Rate limit for API Destinations"
}

variable "api_base_url" {
  description = "Base URL for the API service"
  type        = string
}

variable "response_actions_version" {
  description = "Response Actions version"
  type        = string
  default     = "0.0.15"
}