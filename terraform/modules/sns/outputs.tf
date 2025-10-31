output "critical_topic_arn" {
  description = "ARN of critical alerts topic"
  value       = aws_sns_topic.critical.arn
}

output "high_topic_arn" {
  description = "ARN of high severity alerts topic"
  value       = aws_sns_topic.high.arn
}

output "info_topic_arn" {
  description = "ARN of informational alerts topic"
  value       = aws_sns_topic.info.arn
}
