variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "region" {
  type        = string
  description = "Region for dashboard widgets."
}

variable "alarm_email" {
  type        = string
  description = "Email to subscribe to the alarm topic. Empty disables subscription."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN for SNS encryption."
}

variable "ingestion_queue_name" {
  type        = string
  description = "Ingest queue name."
}

variable "ingestion_dlq_name" {
  type        = string
  description = "Ingest DLQ name."
}

variable "ingestion_dlq_threshold" {
  type        = number
  description = "DLQ depth that trips the alarm."
}

variable "lambda_function_names" {
  type        = list(string)
  description = "Lambda functions to alarm on."
}

variable "catalog_table_name" {
  type        = string
  description = "Catalog table name."
}

variable "api_id" {
  type        = string
  description = "HTTP API id."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
