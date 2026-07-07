variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN for encryption."
}

variable "archive_bucket_arn" {
  type        = string
  description = "ARN of the archive bucket."
}

variable "archive_bucket_id" {
  type        = string
  description = "Name of the archive bucket."
}

variable "catalog_table_arn" {
  type        = string
  description = "ARN of the catalog table."
}

variable "catalog_table_name" {
  type        = string
  description = "Name of the catalog table."
}

variable "lambda_runtime" {
  type        = string
  description = "Lambda runtime."
}

variable "lambda_architecture" {
  type        = string
  description = "Lambda CPU architecture."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet ids for Lambda placement."
}

variable "security_group_id" {
  type        = string
  description = "Security group id for Lambdas."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
