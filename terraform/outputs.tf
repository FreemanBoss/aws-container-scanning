output "ecr_repository_urls" {
  description = "URLs of created ECR repositories"
  value       = { for k, v in module.ecr : k => v.repository_url }
}

output "ecr_repository_arns" {
  description = "ARNs of created ECR repositories"
  value       = { for k, v in module.ecr : k => v.repository_arn }
}

output "scan_results_table_name" {
  description = "Name of the DynamoDB table storing scan results"
  value       = module.dynamodb.scan_results_table_name
}

output "scan_results_table_arn" {
  description = "ARN of the DynamoDB table storing scan results"
  value       = module.dynamodb.scan_results_table_arn
}

output "vulnerability_inventory_table_name" {
  description = "Name of the DynamoDB table storing vulnerability inventory"
  value       = module.dynamodb.vulnerability_inventory_table_name
}

output "lambda_function_arns" {
  description = "ARNs of Lambda functions"
  value = {
    scan_processor           = module.lambda.scan_processor_arn
    vulnerability_aggregator = module.lambda.vulnerability_aggregator_arn
    policy_enforcer          = module.lambda.policy_enforcer_arn
    slack_notifier           = module.lambda.slack_notifier_arn
  }
}

output "sns_topic_arns" {
  description = "ARNs of SNS topics"
  value = {
    critical = module.sns.critical_topic_arn
    high     = module.sns.high_topic_arn
    info     = module.sns.info_topic_arn
  }
}

output "eventbridge_rule_arns" {
  description = "ARNs of EventBridge rules"
  value       = module.eventbridge.rule_arns
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}

output "inspector_status" {
  description = "Status of Amazon Inspector v2"
  value       = var.enable_inspector ? "Enabled" : "Disabled"
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.ecr_encryption.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.ecr_encryption.arn
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value = <<-EOT
  
  ✅ Infrastructure deployed successfully!
  
  Next steps:
  
  1. Configure Inspector v2:
     aws inspector2 enable --resource-types ECR --region ${var.aws_region}
  
  2. Get ECR login:
     aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", values(module.ecr)[0].repository_url)[0]}
  
  3. Build and push a sample image:
     cd sample-apps/vulnerable-app
     docker build -t sample-app:v1.0 .
     docker tag sample-app:v1.0 ${values(module.ecr)[0].repository_url}:v1.0
     docker push ${values(module.ecr)[0].repository_url}:v1.0
  
  4. View scan results:
     aws ecr describe-image-scan-findings --repository-name sample-app --image-id imageTag=v1.0 --region ${var.aws_region}
  
  5. Access CloudWatch Dashboard:
     ${module.monitoring.dashboard_name}
  
  EOT
}
