# Monitoring Module - CloudWatch Dashboards and Alarms

variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "scan_results_table_name" { type = string }
variable "lambda_function_names" { type = map(string) }
variable "ecr_repository_names" { type = list(string) }
variable "enable_detailed_monitoring" { type = bool }
variable "scan_processor_log_group_name" { type = string }
variable "tags" { type = map(string) }

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "security_overview" {
  dashboard_name = "${var.project_name}-security-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Scan Processor" }],
            ["...", { stat = "Sum", label = "Vulnerability Aggregator" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Invocations"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum" }],
            [".", "Throttles", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Errors & Throttles"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "DynamoDB Capacity"
        }
      }
    ]
  })
}

# CloudWatch Alarm: Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.project_name}-${each.key}-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function ${each.value} error count exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

# CloudWatch Alarm: Lambda Duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.project_name}-${each.key}-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 30000
  alarm_description   = "Lambda function ${each.value} duration exceeded 30 seconds"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

# CloudWatch Log Metric Filter: Critical Vulnerabilities Found
resource "aws_cloudwatch_log_metric_filter" "critical_vulnerabilities" {
  name           = "${var.project_name}-critical-vulnerabilities-${var.environment}"
  log_group_name = var.scan_processor_log_group_name
  pattern        = "[severity=CRITICAL]"

  metric_transformation {
    name      = "CriticalVulnerabilities"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    unit      = "None"
  }
}

# CloudWatch Alarm: Critical Vulnerabilities
resource "aws_cloudwatch_metric_alarm" "critical_vulnerabilities" {
  alarm_name          = "${var.project_name}-critical-vulnerabilities-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CriticalVulnerabilities"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Critical vulnerabilities detected in container images"
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# Outputs
output "dashboard_name" {
  value = aws_cloudwatch_dashboard.security_overview.dashboard_name
}

output "dashboard_arn" {
  value = aws_cloudwatch_dashboard.security_overview.dashboard_arn
}
