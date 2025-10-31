# DynamoDB Table: Scan Results
resource "aws_dynamodb_table" "scan_results" {
  name         = "${var.project_name}-scan-results-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "image_digest"
  range_key    = "scan_timestamp"

  attribute {
    name = "image_digest"
    type = "S"
  }

  attribute {
    name = "scan_timestamp"
    type = "N"
  }

  attribute {
    name = "repository_name"
    type = "S"
  }

  attribute {
    name = "policy_status"
    type = "S"
  }

  # Global Secondary Index: Search by repository
  global_secondary_index {
    name            = "repository-scan-index"
    hash_key        = "repository_name"
    range_key       = "scan_timestamp"
    projection_type = "ALL"
  }

  # Global Secondary Index: Search by policy status
  global_secondary_index {
    name            = "policy-status-index"
    hash_key        = "policy_status"
    range_key       = "scan_timestamp"
    projection_type = "ALL"
  }

  # Time to Live
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-scan-results-${var.environment}"
    }
  )
}

# DynamoDB Table: Vulnerability Inventory
resource "aws_dynamodb_table" "vulnerability_inventory" {
  name         = "${var.project_name}-vulnerability-inventory-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "cve_id"
  range_key    = "package_name"

  attribute {
    name = "cve_id"
    type = "S"
  }

  attribute {
    name = "package_name"
    type = "S"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  # Global Secondary Index: Search by severity
  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "cve_id"
    projection_type = "ALL"
  }

  # Time to Live
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vulnerability-inventory-${var.environment}"
    }
  )
}
