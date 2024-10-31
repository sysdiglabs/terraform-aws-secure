// Values required to create access entries
variable "cspm_role_arn" {
  description = "(Required) The Full ARN of the Sysdig CSPM role which will be used to access Kubernetes clusters"
  type        = string
}

variable "trusted_identity" {
  type        = string
  description = "This value should be provided by Sysdig. The field refers to Sysdig's IAM role that will be authorized to pull ECR images"
}

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

variable "org_units" {
  description = "(Optional) List of Organization Unit IDs in which to setup Agentless Workload Scanning. By default, Agentless Workload Scanning will be setup in all accounts within the Organization. This field is ignored if `is_organizational = false`"
  type        = set(string)
  default     = []
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

variable "eks_scanning_enabled" {
    type        = bool
    description = "Set this field to 'true' to deploy Agentless Workload Scanning for EKS clusters"
    default     = false
}

variable "eks_clusters" {
  description = "(Optional) List the clusters that Sysdig will scan. Please note that only clusters with authentication mode set to API or API_AND_CONFIG_MAP will be onboarded."
  type        = set(string)
  default     = []
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