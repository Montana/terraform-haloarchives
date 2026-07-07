output "ingest_lambda_arn" {
  description = "ARN of the ingest Lambda."
  value       = aws_lambda_function.ingest.arn
}

output "ingest_lambda_name" {
  description = "Name of the ingest Lambda."
  value       = aws_lambda_function.ingest.function_name
}

output "catalog_writer_lambda_name" {
  description = "Name of the catalog-writer Lambda."
  value       = aws_lambda_function.catalog_writer.function_name
}

output "queue_name" {
  description = "Ingest queue name."
  value       = aws_sqs_queue.ingest.name
}

output "dlq_name" {
  description = "Ingest DLQ name."
  value       = aws_sqs_queue.dlq.name
}
