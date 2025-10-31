# EventBridge Module - Event-driven architecture for scan processing

variable "project_name" { type = string }
variable "environment" { type = string }
variable "scan_processor_arn" { type = string }
variable "scan_processor_name" { type = string }
variable "vulnerability_aggregator_arn" { type = string }
variable "vulnerability_aggregator_name" { type = string }
variable "critical_sns_topic_arn" { type = string }
variable "high_sns_topic_arn" { type = string }
variable "vulnerability_severity_threshold" { type = string }
variable "tags" { type = map(string) }

# EventBridge Rule: ECR Scan Complete
resource "aws_cloudwatch_event_rule" "ecr_scan_complete" {
  name        = "${var.project_name}-ecr-scan-complete-${var.environment}"
  description = "Trigger when ECR image scan completes"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      scan-status = ["COMPLETE"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ecr_scan_to_lambda" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_complete.name
  target_id = "ScanProcessor"
  arn       = var.scan_processor_arn
}

resource "aws_lambda_permission" "allow_eventbridge_ecr_scan" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.scan_processor_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_scan_complete.arn
}

# EventBridge Rule: Inspector Findings - Critical
resource "aws_cloudwatch_event_rule" "inspector_critical" {
  name        = "${var.project_name}-inspector-critical-${var.environment}"
  description = "Trigger on CRITICAL Inspector findings"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = ["CRITICAL"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "inspector_critical_to_lambda" {
  rule      = aws_cloudwatch_event_rule.inspector_critical.name
  target_id = "ScanProcessorCritical"
  arn       = var.scan_processor_arn
}

resource "aws_cloudwatch_event_target" "inspector_critical_to_sns" {
  rule      = aws_cloudwatch_event_rule.inspector_critical.name
  target_id = "SNSCritical"
  arn       = var.critical_sns_topic_arn
}

resource "aws_lambda_permission" "allow_eventbridge_inspector_critical" {
  statement_id  = "AllowExecutionFromEventBridgeInspectorCritical"
  action        = "lambda:InvokeFunction"
  function_name = var.scan_processor_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inspector_critical.arn
}

# EventBridge Rule: Inspector Findings - High
resource "aws_cloudwatch_event_rule" "inspector_high" {
  name        = "${var.project_name}-inspector-high-${var.environment}"
  description = "Trigger on HIGH Inspector findings"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = ["HIGH"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "inspector_high_to_lambda" {
  rule      = aws_cloudwatch_event_rule.inspector_high.name
  target_id = "ScanProcessorHigh"
  arn       = var.scan_processor_arn
}

resource "aws_cloudwatch_event_target" "inspector_high_to_sns" {
  rule      = aws_cloudwatch_event_rule.inspector_high.name
  target_id = "SNSHigh"
  arn       = var.high_sns_topic_arn
}

resource "aws_lambda_permission" "allow_eventbridge_inspector_high" {
  statement_id  = "AllowExecutionFromEventBridgeInspectorHigh"
  action        = "lambda:InvokeFunction"
  function_name = var.scan_processor_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inspector_high.arn
}

# EventBridge Rule: Scheduled Aggregation
resource "aws_cloudwatch_event_rule" "scheduled_aggregation" {
  name                = "${var.project_name}-scheduled-aggregation-${var.environment}"
  description         = "Run vulnerability aggregation daily"
  schedule_expression = "rate(24 hours)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "scheduled_to_aggregator" {
  rule      = aws_cloudwatch_event_rule.scheduled_aggregation.name
  target_id = "VulnerabilityAggregator"
  arn       = var.vulnerability_aggregator_arn
}

resource "aws_lambda_permission" "allow_eventbridge_scheduled" {
  statement_id  = "AllowExecutionFromEventBridgeScheduled"
  action        = "lambda:InvokeFunction"
  function_name = var.vulnerability_aggregator_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_aggregation.arn
}

# Outputs
output "rule_arns" {
  value = {
    ecr_scan_complete       = aws_cloudwatch_event_rule.ecr_scan_complete.arn
    inspector_critical      = aws_cloudwatch_event_rule.inspector_critical.arn
    inspector_high          = aws_cloudwatch_event_rule.inspector_high.arn
    scheduled_aggregation   = aws_cloudwatch_event_rule.scheduled_aggregation.arn
  }
}
