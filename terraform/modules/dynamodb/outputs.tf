output "scan_results_table_name" {
  description = "Name of scan results table"
  value       = aws_dynamodb_table.scan_results.name
}

output "scan_results_table_arn" {
  description = "ARN of scan results table"
  value       = aws_dynamodb_table.scan_results.arn
}

output "vulnerability_inventory_table_name" {
  description = "Name of vulnerability inventory table"
  value       = aws_dynamodb_table.vulnerability_inventory.name
}

output "vulnerability_inventory_table_arn" {
  description = "ARN of vulnerability inventory table"
  value       = aws_dynamodb_table.vulnerability_inventory.arn
}
