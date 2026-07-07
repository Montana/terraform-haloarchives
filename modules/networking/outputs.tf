output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnet ids for Lambda placement."
  value       = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  description = "Security group id attached to platform Lambdas."
  value       = aws_security_group.lambda.id
}
