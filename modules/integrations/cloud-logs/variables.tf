variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account)"
}

variable "folder_arn" {
  description = "(Required) The ARN of your CloudTrail Bucket Folder"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning"

  default = {
    "product" = "sysdig-secure-for-cloud"
  }
}

variable "name" {
  description = "(Optional) Name to be assigned to all child resources. A suffix may be added internally when required. Use default value unless you need to install multiple instances"
  type        = string
  default     = "sysdig-secure-cloudlogs"
}

variable "regions" {
  description = "(Optional) The list of AWS regions we want to scrape data from"
  type        = set(string)
  default     = []
}

variable "is_gov_cloud_onboarding" {
  type        = bool
  default     = false
  description = "true/false whether secure-for-cloud should be deployed in a govcloud account/org or not"
}

variable "topic_arn" {
  type        = string
  description = "SNS Topic ARN that will forward CloudTrail notifications to Sysdig Secure"

  validation {
    condition     = var.topic_arn != ""
    error_message = "Topic ARN must not be empty"
  }

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):sns:[a-z0-9-]+:[0-9]+:.+$", var.topic_arn))
    error_message = "Topic ARN must be a valid SNS ARN format"
  }
}

variable "create_topic" {
  type        = bool
  default     = false
  description = "true/false whether terraform should create the SNS Topic"
}
