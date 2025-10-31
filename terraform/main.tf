terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for remote state storage
  # Uncomment and configure after creating S3 bucket and DynamoDB table
  # backend "s3" {
  #   bucket         = "terraform-state-ACCOUNT_ID"
  #   key            = "container-scanning/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        Project     = var.project_name
        ManagedBy   = "Terraform"
      }
    )
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS key for ECR encryption
resource "aws_kms_key" "ecr_encryption" {
  description             = "KMS key for ECR encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key"
        Effect = "Allow"
        Principal = {
          AWS = module.lambda.lambda_execution_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecr-key"
  }
}

resource "aws_kms_alias" "ecr_encryption" {
  name          = "alias/${var.project_name}-ecr"
  target_key_id = aws_kms_key.ecr_encryption.key_id
}

# Modules
module "ecr" {
  source = "./modules/ecr"

  for_each = { for repo in var.ecr_repositories : repo.name => repo }

  repository_name      = each.value.name
  image_tag_mutability = each.value.image_tag_mutability
  scan_on_push         = each.value.scan_on_push
  encryption_type      = each.value.encryption_type
  kms_key_arn          = aws_kms_key.ecr_encryption.arn
  lifecycle_policy     = var.ecr_lifecycle_policy
  environment          = var.environment
  
  enable_cross_region_replication = var.enable_cross_region_replication
  replication_region             = var.replication_region

  tags = var.tags
}

module "inspector" {
  source = "./modules/inspector"

  enable_inspector      = var.enable_inspector
  resource_types        = var.inspector_resource_types
  environment           = var.environment
  
  tags = var.tags
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project_name                  = var.project_name
  environment                   = var.environment
  billing_mode                  = var.dynamodb_billing_mode
  enable_point_in_time_recovery = var.dynamodb_point_in_time_recovery

  tags = var.tags
}

module "sns" {
  source = "./modules/sns"

  project_name      = var.project_name
  environment       = var.environment
  alert_email       = var.alert_email
  kms_key_id        = aws_kms_key.ecr_encryption.id

  tags = var.tags
}

module "lambda" {
  source = "./modules/lambda"

  project_name                     = var.project_name
  environment                      = var.environment
  runtime                          = var.lambda_runtime
  timeout                          = var.lambda_timeout
  memory_size                      = var.lambda_memory_size
  
  scan_results_table_name          = module.dynamodb.scan_results_table_name
  vulnerability_inventory_table_name = module.dynamodb.vulnerability_inventory_table_name
  
  critical_sns_topic_arn           = module.sns.critical_topic_arn
  high_sns_topic_arn               = module.sns.high_topic_arn
  info_sns_topic_arn               = module.sns.info_topic_arn
  
  slack_webhook_url                = var.slack_webhook_url
  vulnerability_severity_threshold = var.vulnerability_severity_threshold
  block_on_critical                = var.block_on_critical
  block_on_high                    = var.block_on_high
  
  subnet_ids                       = var.subnet_ids
  vpc_id                           = var.vpc_id
  
  log_retention_days               = var.log_retention_days

  tags = var.tags
}

module "eventbridge" {
  source = "./modules/eventbridge"

  project_name                       = var.project_name
  environment                        = var.environment
  
  scan_processor_arn                 = module.lambda.scan_processor_arn
  scan_processor_name                = module.lambda.scan_processor_name
  vulnerability_aggregator_arn       = module.lambda.vulnerability_aggregator_arn
  vulnerability_aggregator_name      = module.lambda.vulnerability_aggregator_name
  
  critical_sns_topic_arn             = module.sns.critical_topic_arn
  high_sns_topic_arn                 = module.sns.high_topic_arn
  
  vulnerability_severity_threshold   = var.vulnerability_severity_threshold

  tags = var.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name                      = var.project_name
  environment                       = var.environment
  aws_region                        = var.aws_region
  
  scan_results_table_name           = module.dynamodb.scan_results_table_name
  lambda_function_names             = {
    scan_processor           = module.lambda.scan_processor_name
    vulnerability_aggregator = module.lambda.vulnerability_aggregator_name
    policy_enforcer          = module.lambda.policy_enforcer_name
    slack_notifier           = module.lambda.slack_notifier_name
  }
  
  ecr_repository_names              = [for repo in var.ecr_repositories : repo.name]
  scan_processor_log_group_name     = module.lambda.scan_processor_log_group_name
  
  enable_detailed_monitoring        = var.enable_detailed_monitoring

  tags = var.tags
}

# VPC Endpoints (optional, for enhanced security)
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"
  count  = var.create_vpc_endpoints ? 1 : 0

  vpc_id     = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids
  
  tags = var.tags
}

# Data sources for default VPC (used only if vpc_id not provided)
data "aws_vpc" "default" {
  count   = var.vpc_id == "" && var.create_vpc_endpoints ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = length(var.subnet_ids) == 0 && var.create_vpc_endpoints ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}
