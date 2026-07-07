output "table_name" {
  description = "Catalog table name."
  value       = aws_dynamodb_table.catalog.name
}

output "table_arn" {
  description = "Catalog table ARN."
  value       = aws_dynamodb_table.catalog.arn
}

output "stream_arn" {
  description = "DynamoDB stream ARN."
  value       = aws_dynamodb_table.catalog.stream_arn
}
