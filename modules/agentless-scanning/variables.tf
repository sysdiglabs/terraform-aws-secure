variable "scanning_account_id" {
  type        = string
  description = "The identifier of the account that will receive volume snapshots"
  default     = "878070807337"
}

variable "kms_key_deletion_window" {
  description = "Deletion window for shared KMS key"
  type        = number
  default     = 7
}

variable "name" {
  description = "The name of the installation. Assigned to most child resource(s)"
  type        = string
  default     = "sysdig-secure-scanning"
}

variable "tags" {
  type        = map(string)
  description = "sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning"
  default = {
    "product" = "sysdig-secure-for-cloud"
  }
}

variable "is_organizational" {
  description = "(Optional) Set this field to 'true' to deploy Agentless Scanning to an AWS Organization (Or specific OUs)"
  type        = bool
  default     = false
}

variable "org_units" {
  description = "(Optional) List of Organization Unit IDs in which to setup Agentless Scanning. By default, Agentless Scanning will be setup in all accounts within the Organization. This field is ignored if `is_organizational = false`"
  type        = set(string)
  default     = []
}

variable "regions" {
  description = "(Optional) List of regions in which to install Agentless Scanning"
  type        = set(string)
  default     = []
}

variable "auto_create_stackset_roles" {
  description = "Whether to auto create the custom stackset roles to run SELF_MANAGED stackset. Default is true"
  type        = bool
  default     = true
}

variable "stackset_admin_role_arn" {
  description = "(Optional) stackset admin role to run SELF_MANAGED stackset"
  type        = string
  default     = ""
}

variable "stackset_execution_role_name" {
  description = "(Optional) stackset execution role name to run SELF_MANAGED stackset"
  type        = string
  default     = ""
}

variable "timeout" {
  type        = string
  description = "Default timeout values for create, update, and delete operations"
  default     = "30m"
}

variable "mgt_stackset" {
  description = "(Optional) Indicates if the management stackset should be deployed"
  type        = bool
  default     = true
}

variable "failure_tolerance_percentage" {
  type        = number
  description = "The percentage of accounts, per Region, for which stack operations can fail before AWS CloudFormation stops the operation in that Region"
  default     = 90
}

variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Agentless Scanning for (incase of organization, ID of the Sysdig management account)"
}

variable "organization_accounts_to_exclude" {
  type        = list(string)
  default     = []
  description = "AWS account IDs to exclude from organizational deployment"
}
