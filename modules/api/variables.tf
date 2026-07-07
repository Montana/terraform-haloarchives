variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "ingest_lambda_arn" {
  type        = string
  description = "Invoke ARN of the ingest Lambda."
}

variable "ingest_lambda_name" {
  type        = string
  description = "Name of the ingest Lambda."
}

variable "retrieval_state_machine" {
  type        = string
  description = "ARN of the retrieval state machine."
}

variable "retrieval_start_role_arn" {
  type        = string
  description = "Role ARN API Gateway assumes to start executions."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
