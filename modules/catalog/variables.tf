variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN for table encryption."
}

variable "billing_mode" {
  type        = string
  description = "PAY_PER_REQUEST or PROVISIONED."
}

variable "point_in_time_recovery" {
  type        = bool
  description = "Enable PITR."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
