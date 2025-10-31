output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "scan_processor_function_arn" {
  description = "ARN of the scan processor Lambda function"
  value       = aws_lambda_function.scan_processor.arn
}

output "vulnerability_aggregator_function_arn" {
  description = "ARN of the vulnerability aggregator Lambda function"
  value       = aws_lambda_function.vulnerability_aggregator.arn
}

output "policy_enforcer_function_arn" {
  description = "ARN of the policy enforcer Lambda function"
  value       = aws_lambda_function.policy_enforcer.arn
}

output "slack_notifier_function_arn" {
  description = "ARN of the slack notifier Lambda function"
  value       = aws_lambda_function.slack_notifier.arn
}
