output "kms_key_arn" {
  description = "ARN of the primary CMK."
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "Key id of the primary CMK."
  value       = aws_kms_key.main.key_id
}

output "replica_kms_key_arn" {
  description = "ARN of the replica-region CMK."
  value       = aws_kms_key.replica.arn
}
