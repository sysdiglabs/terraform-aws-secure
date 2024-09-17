variable "sysdig_secure_account_id" {
  type        = string
  description = "ID of the Sysdig Cloud Account to enable Cloud Logs integration for (in case of organization, ID of the Sysdig management account)"
}

variable "folder_arn" {
  description = "(Required) The ARN of your CloudTrail Bucket Folder"
  type        = string
}

variable "bucket_arn" {
  description = "(Required) The ARN of your s3 bucket associated with your Cloudtrail trail"
  type        = string
}

variable "region" {
  description = "Region in which to deploy singleton resources such as Stacksets."
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