variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account)"
}

variable "is_organizational" {
  description = "(Optional) Set this field to 'true' to deploy CloudLogs to an AWS Organization (Or specific OUs)"
  type        = bool
  default     = false
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

variable "role_arn" {
  type        = string
  description = "ARN of the role that terraform will create to download the CloudTrail logs from the S3 bucket."
  default     = null

  validation {
    condition     = var.role_arn == null || can(regex("^arn:(aws|aws-us-gov):iam::[0-9]+:role/.+$", var.role_arn))
    error_message = "Role ARN must be a valid IAM ARN format"
  }
}

variable "role_name" {
  type        = string
  description = "Name for the Role that Terraform will create to download the CloudTrail logs from the S3 bucket. Alternative to the `role_arn`"
  default     = null
}

variable "bucket_account_id" {
  type        = string
  default     = null
  description = "(Optional) AWS Account ID that owns the S3 bucket, if different from the account where the module is being applied. Required for organizational cross-account deployments."
}

variable "timeout" {
  description = "The maximum amount of time that Terraform will wait for the StackSet operation to complete"
  type        = string
  default     = "30m"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the S3 bucket. If provided, the IAM role will be granted decrypt permissions."
  type        = string
  default     = null
}

variable "wait_after_basic_seconds" {
  type        = number
  description = "Number of seconds to wait after CIEM basic before proceeding (set to 0 to disable)."
  default     = 30
}
