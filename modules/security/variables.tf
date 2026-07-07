variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "account_id" {
  type        = string
  description = "AWS account id."
}

variable "region" {
  type        = string
  description = "Primary region (used in the KMS key policy for CloudWatch Logs)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
