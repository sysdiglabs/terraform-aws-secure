variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "function_zip_file" {
  description = "Path to the local Lambda deployment package zip file (optional, for local mode)"
  type        = string
  default     = null
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.13"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memory (MB) to allocate to the Lambda function"
  type        = number
  default     = 128
}

variable "function_policies" {
  description = "List of policy documents for the Lambda function"
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "response_actions_version" {
  description = "Name of the IAM role to assume for cross-account operations"
  type        = string
}

variable "arn_prefix" {
  description = "The prefix for any AWS ARN"
  type        = "string"
}