# Lambda Module - Placeholder for Lambda function deployment
# Lambda source code will be created in src/lambda-functions/

# This module creates IAM roles, CloudWatch log groups, and placeholder Lambda functions
# The actual function code will be packaged and deployed separately

variable "project_name" { type = string }
variable "environment" { type = string }
variable "runtime" { type = string }
variable "timeout" { type = number }
variable "memory_size" { type = number }
variable "scan_results_table_name" { type = string }
variable "vulnerability_inventory_table_name" { type = string }
variable "critical_sns_topic_arn" { type = string }
variable "high_sns_topic_arn" { type = string }
variable "info_sns_topic_arn" { type = string }
variable "slack_webhook_url" { type = string }
variable "vulnerability_severity_threshold" { type = string }
variable "block_on_critical" { type = bool }
variable "block_on_high" { type = bool }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "log_retention_days" { type = number }
variable "tags" { type = map(string) }

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeImageScanFindings",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:PutImageTagMutability",
          "ecr:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "inspector2:GetFindings",
          "inspector2:ListFindings",
          "inspector2:BatchGetFreeTrialInfo"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.scan_results_table_name}",
          "arn:aws:dynamodb:*:*:table/${var.scan_results_table_name}/*",
          "arn:aws:dynamodb:*:*:table/${var.vulnerability_inventory_table_name}",
          "arn:aws:dynamodb:*:*:table/${var.vulnerability_inventory_table_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          var.critical_sns_topic_arn,
          var.high_sns_topic_arn,
          var.info_sns_topic_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach VPC execution policy if VPC is configured
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function: Scan Processor
resource "aws_lambda_function" "scan_processor" {
  filename      = "${path.module}/../../../build/scan-processor.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../build/scan-processor.zip")
  function_name = "${var.project_name}-scan-processor-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.lambda_handler"
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  environment {
    variables = {
      SCAN_RESULTS_TABLE              = var.scan_results_table_name
      VULNERABILITY_INVENTORY_TABLE   = var.vulnerability_inventory_table_name
      CRITICAL_SNS_TOPIC             = var.critical_sns_topic_arn
      HIGH_SNS_TOPIC                 = var.high_sns_topic_arn
      VULNERABILITY_THRESHOLD        = var.vulnerability_severity_threshold
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-scan-processor-${var.environment}" })
}

# CloudWatch Log Group for Scan Processor
resource "aws_cloudwatch_log_group" "scan_processor" {
  name              = "/aws/lambda/${aws_lambda_function.scan_processor.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function: Vulnerability Aggregator
resource "aws_lambda_function" "vulnerability_aggregator" {
  filename      = "${path.module}/../../../build/vulnerability-aggregator.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../build/vulnerability-aggregator.zip")
  function_name = "${var.project_name}-vulnerability-aggregator-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.lambda_handler"
  runtime       = var.runtime
  timeout       = 300
  memory_size   = 1024

  environment {
    variables = {
      SCAN_RESULTS_TABLE            = var.scan_results_table_name
      VULNERABILITY_INVENTORY_TABLE = var.vulnerability_inventory_table_name
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-vulnerability-aggregator-${var.environment}" })
}

resource "aws_cloudwatch_log_group" "vulnerability_aggregator" {
  name              = "/aws/lambda/${aws_lambda_function.vulnerability_aggregator.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function: Policy Enforcer
resource "aws_lambda_function" "policy_enforcer" {
  filename      = "${path.module}/../../../build/policy-enforcer.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../build/policy-enforcer.zip")
  function_name = "${var.project_name}-policy-enforcer-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.lambda_handler"
  runtime       = var.runtime
  timeout       = 30
  memory_size   = var.memory_size

  environment {
    variables = {
      BLOCK_ON_CRITICAL = var.block_on_critical
      BLOCK_ON_HIGH     = var.block_on_high
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-policy-enforcer-${var.environment}" })
}

resource "aws_cloudwatch_log_group" "policy_enforcer" {
  name              = "/aws/lambda/${aws_lambda_function.policy_enforcer.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function: Slack Notifier
resource "aws_lambda_function" "slack_notifier" {
  filename      = "${path.module}/../../../build/slack-notifier.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../build/slack-notifier.zip")
  function_name = "${var.project_name}-slack-notifier-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.lambda_handler"
  runtime       = var.runtime
  timeout       = 15
  memory_size   = 256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-slack-notifier-${var.environment}" })
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
  name              = "/aws/lambda/${aws_lambda_function.slack_notifier.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Note: Lambda packages are created by scripts/package-lambdas.py
# Run: python3 scripts/package-lambdas.py before terraform apply

# Outputs
output "scan_processor_arn" { value = aws_lambda_function.scan_processor.arn }
output "scan_processor_name" { value = aws_lambda_function.scan_processor.function_name }
output "scan_processor_log_group_name" { value = aws_cloudwatch_log_group.scan_processor.name }
output "vulnerability_aggregator_arn" { value = aws_lambda_function.vulnerability_aggregator.arn }
output "vulnerability_aggregator_name" { value = aws_lambda_function.vulnerability_aggregator.function_name }
output "policy_enforcer_arn" { value = aws_lambda_function.policy_enforcer.arn }
output "policy_enforcer_name" { value = aws_lambda_function.policy_enforcer.function_name }
output "slack_notifier_arn" { value = aws_lambda_function.slack_notifier.arn }
output "slack_notifier_name" { value = aws_lambda_function.slack_notifier.function_name }
