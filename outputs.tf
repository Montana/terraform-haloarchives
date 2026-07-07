output "archive_bucket" {
  description = "Name of the primary archive (WORM) bucket."
  value       = module.storage.archive_bucket_id
}

output "catalog_table" {
  description = "DynamoDB catalog table name."
  value       = module.catalog.table_name
}

output "api_endpoint" {
  description = "Base URL for the HaloArchives HTTP API."
  value       = module.api.api_endpoint
}

output "retrieval_state_machine_arn" {
  description = "Step Functions state machine handling async Glacier retrievals."
  value       = module.retrieval.state_machine_arn
}

output "kms_key_arn" {
  description = "Customer-managed KMS key protecting archives and catalog."
  value       = module.security.kms_key_arn
}

output "dashboard_url" {
  description = "CloudWatch dashboard for the platform."
  value       = module.observability.dashboard_url
}

output "vpc_id" {
  description = "VPC hosting private compute."
  value       = module.networking.vpc_id
}
