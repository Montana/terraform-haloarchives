output "archive_bucket_id" {
  description = "Name of the primary archive bucket."
  value       = aws_s3_bucket.archive.id
}

output "archive_bucket_arn" {
  description = "ARN of the primary archive bucket."
  value       = aws_s3_bucket.archive.arn
}

output "logs_bucket_id" {
  description = "Name of the access-logs bucket."
  value       = aws_s3_bucket.logs.id
}

output "replica_bucket_arn" {
  description = "ARN of the replica bucket (null when replication disabled)."
  value       = try(aws_s3_bucket.replica[0].arn, null)
}
