# SNS Topic: Critical Alerts
resource "aws_sns_topic" "critical" {
  name              = "${var.project_name}-critical-alerts-${var.environment}"
  display_name      = "Critical Security Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name     = "${var.project_name}-critical-alerts-${var.environment}"
      Severity = "CRITICAL"
    }
  )
}

resource "aws_sns_topic_policy" "critical" {
  arn = aws_sns_topic.critical.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical.arn
      }
    ]
  })
}

# Email subscription for critical alerts
resource "aws_sns_topic_subscription" "critical_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic: High Severity Alerts
resource "aws_sns_topic" "high" {
  name              = "${var.project_name}-high-alerts-${var.environment}"
  display_name      = "High Severity Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name     = "${var.project_name}-high-alerts-${var.environment}"
      Severity = "HIGH"
    }
  )
}

resource "aws_sns_topic_policy" "high" {
  arn = aws_sns_topic.high.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.high.arn
      }
    ]
  })
}

# Email subscription for high alerts
resource "aws_sns_topic_subscription" "high_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.high.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic: Informational Alerts
resource "aws_sns_topic" "info" {
  name              = "${var.project_name}-info-alerts-${var.environment}"
  display_name      = "Informational Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name     = "${var.project_name}-info-alerts-${var.environment}"
      Severity = "INFO"
    }
  )
}

resource "aws_sns_topic_policy" "info" {
  arn = aws_sns_topic.info.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.info.arn
      }
    ]
  })
}
