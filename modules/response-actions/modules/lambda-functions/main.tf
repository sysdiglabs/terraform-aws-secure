# Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.function_name}-role"
  }
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Validation using check blocks (Terraform 1.5+)
check "deployment_mode_validation" {
  assert {
    error_message = "Either local mode (function_zip_file) or S3 mode (s3_bucket, s3_key, s3_key_sha256) must be properly configured."
  }
}

data "http" "lambda_zip_resource" {
  url = "https://download.sysdig.com/cloud-response-actions/v${var.response_actions_version}/${var.function_zip_file}"
}

resource "local_file" "lambda_zip_file" {
  filename = "${path.module}/lambda.zip"
  content  = data.http.lambda_zip_resource.body
}

# Local values for hash calculation
locals {
  function_sha256 = filebase64sha256(var.function_zip_file)

  # Merge environment variables with DELEGATE_ROLE_NAME if provided
  merged_environment_variables = merge(
    var.environment_variables,
    {
      # This will be the name of the role assumed in subaccounts.
      # It's the name is conventionally the same as the one assumed by the lambda itself upon execution.
      DELEGATE_ROLE_NAME = aws_iam_role.lambda_execution_role.name
    }
  )
}

# Inline (to avoid quota issues) custom policies for the Lambda execution role
resource "aws_iam_role_policy" "function_policies" {
  count = length(var.function_policies)

  name = "${var.function_name}-custom-policy-${count.index + 1}"
  role = aws_iam_role.lambda_execution_role.id

  policy = var.function_policies[count.index]
}

# CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.function_name}-logs"
    "sysdig.com/response-actions/cloud-actions" = "true"
  }
}

# Lambda function
resource "aws_lambda_function" "function" {
  # Local mode configuration
  filename         = local_file.lambda_zip_file.filename

  function_name    = var.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  source_code_hash = local.function_sha256
  publish = true

  dynamic "environment" {
    for_each = length(local.merged_environment_variables) > 0 ? [1] : []
    content {
      variables = local.merged_environment_variables
    }
  }

  tags = {
    Name = var.function_name
    "sysdig.com/response-actions/cloud-actions" = "true"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}
