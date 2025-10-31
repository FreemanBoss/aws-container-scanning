# Development Environment Terraform Configuration

terraform {
  required_version = ">= 1.5.0"

  # Uncomment after creating S3 bucket and DynamoDB table
  # backend "s3" {
  #   bucket         = "terraform-state-REPLACE_WITH_ACCOUNT_ID"
  #   key            = "container-scanning/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Use root module with all variables from terraform.tfvars
module "container_scanning" {
  source = "../.."

  # Pass all variables from terraform.tfvars
  aws_region                      = var.aws_region
  environment                     = var.environment
  project_name                    = var.project_name
  ecr_repositories                = var.ecr_repositories
  ecr_lifecycle_policy            = var.ecr_lifecycle_policy
  enable_inspector                = var.enable_inspector
  inspector_resource_types        = var.inspector_resource_types
  lambda_runtime                  = var.lambda_runtime
  lambda_timeout                  = var.lambda_timeout
  lambda_memory_size              = var.lambda_memory_size
  dynamodb_billing_mode           = var.dynamodb_billing_mode
  dynamodb_point_in_time_recovery = var.dynamodb_point_in_time_recovery
  alert_email                     = var.alert_email
  slack_webhook_url               = var.slack_webhook_url
  vulnerability_severity_threshold = var.vulnerability_severity_threshold
  block_on_critical               = var.block_on_critical
  block_on_high                   = var.block_on_high
  create_vpc_endpoints            = var.create_vpc_endpoints
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  log_retention_days              = var.log_retention_days
  enable_detailed_monitoring      = var.enable_detailed_monitoring
  compliance_frameworks           = var.compliance_frameworks
  enable_cross_region_replication = var.enable_cross_region_replication
  replication_region              = var.replication_region
  tags                            = var.tags
}

# Variable declarations for this environment
variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "ecr_repositories" { type = list(object({ name = string, image_tag_mutability = string, scan_on_push = bool, encryption_type = string })) }
variable "ecr_lifecycle_policy" { type = object({ untagged_days = number, tagged_count = number }) }
variable "enable_inspector" { type = bool }
variable "inspector_resource_types" { type = list(string) }
variable "lambda_runtime" { type = string }
variable "lambda_timeout" { type = number }
variable "lambda_memory_size" { type = number }
variable "dynamodb_billing_mode" { type = string }
variable "dynamodb_point_in_time_recovery" { type = bool }
variable "alert_email" { type = string }
variable "slack_webhook_url" { type = string }
variable "vulnerability_severity_threshold" { type = string }
variable "block_on_critical" { type = bool }
variable "block_on_high" { type = bool }
variable "create_vpc_endpoints" { type = bool }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "log_retention_days" { type = number }
variable "enable_detailed_monitoring" { type = bool }
variable "compliance_frameworks" { type = list(string) }
variable "enable_cross_region_replication" { type = bool }
variable "replication_region" { type = string }
variable "tags" { type = map(string) }

# Environment-specific outputs
output "ecr_repositories" {
  description = "ECR repository details"
  value       = module.container_scanning.ecr_repository_urls
}

output "next_steps" {
  description = "Post-deployment instructions"
  value       = module.container_scanning.deployment_instructions
}
