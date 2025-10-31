# Backend Configuration Variables
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "container-scanning"
}

# Tagging
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "container-scanning"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}

# ECR Configuration
variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type = list(object({
    name                 = string
    image_tag_mutability = string
    scan_on_push         = bool
    encryption_type      = string
  }))
  default = [
    {
      name                 = "sample-app"
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      encryption_type      = "KMS"
    }
  ]
}

variable "ecr_lifecycle_policy" {
  description = "ECR lifecycle policy for untagged images"
  type = object({
    untagged_days = number
    tagged_count  = number
  })
  default = {
    untagged_days = 7
    tagged_count  = 30
  }
}

# Inspector Configuration
variable "enable_inspector" {
  description = "Enable Amazon Inspector v2"
  type        = bool
  default     = true
}

variable "inspector_resource_types" {
  description = "Resource types to scan with Inspector"
  type        = list(string)
  default     = ["ECR"]
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

# SNS Configuration
variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Scanning Configuration
variable "vulnerability_severity_threshold" {
  description = "Minimum severity level to trigger alerts (CRITICAL, HIGH, MEDIUM, LOW)"
  type        = string
  default     = "HIGH"
}

variable "block_on_critical" {
  description = "Block deployment if critical vulnerabilities found"
  type        = bool
  default     = true
}

variable "block_on_high" {
  description = "Block deployment if high vulnerabilities found"
  type        = bool
  default     = false
}

# Network Configuration
variable "create_vpc_endpoints" {
  description = "Create VPC endpoints for ECR, DynamoDB, and S3"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for VPC endpoints (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions"
  type        = list(string)
  default     = []
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

# Compliance Configuration
variable "compliance_frameworks" {
  description = "Compliance frameworks to check against"
  type        = list(string)
  default     = ["CIS", "PCI-DSS"]
}

# Cost Optimization
variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for ECR (prod only)"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Region for ECR cross-region replication"
  type        = string
  default     = "us-west-2"
}
