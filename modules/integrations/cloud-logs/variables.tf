variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account)"
}

variable "bucket_arn" {
  description = "(Required) The ARN of your CloudTrail Bucket"
  type        = string

  validation {
    condition     = var.bucket_arn != ""
    error_message = "Bucket ARN must not be empty"
  }

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):s3:::.*$", var.bucket_arn))
    error_message = "Bucket ARN must be a valid S3 ARN format"
  }
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Sysdig secure-for-cloud tags. always include 'product' default tag for resource-group proper functioning"

  default = {
    "product" = "sysdig-secure-for-cloud"
  }
}

variable "name" {
  description = "(Optional) Name to be assigned to all child resources. A suffix may be added internally when required."
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

variable "kms_key_arns" {
  type        = list(string)
  default     = null
  description = "(Optional) List of KMS Key ARNs used to encrypt the S3 bucket. If provided, the IAM role will be granted permissions to decrypt using these keys."
}

variable "bucket_account_id" {
  type        = string
  default     = null
  description = "(Optional) AWS Account ID that owns the S3 bucket, if different from the account where the module is being applied. If not specified, the current account is assumed to be the bucket owner."
}

variable "failure_tolerance_percentage" {
  description = "The percentage of account deployments that can fail before CloudFormation stops deployment in an organizational unit. Range: 0-100"
  type        = number
  default     = 0
}

variable "timeout" {
  description = "The maximum amount of time that Terraform will wait for the StackSet operation to complete"
  type        = string
  default     = "30m"
}

variable "is_organizational" {
  type        = bool
  description = "Whether this is an organizational deployment using AWS Organizations. If true, service-managed StackSets will be used for cross-account access."
  default     = false
}

variable "org_units" {
  type        = list(string)
  description = "List of AWS Organizations organizational unit (OU) IDs in which to create the StackSet instances. Required if is_organizational is true."
  default     = []
}
