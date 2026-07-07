variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK ARN used to encrypt the primary archive bucket."
}

variable "replica_kms_key_arn" {
  type        = string
  description = "CMK ARN in the replica region."
}

variable "enable_object_lock" {
  type        = bool
  description = "Enable S3 Object Lock (WORM)."
}

variable "object_lock_retention_days" {
  type        = number
  description = "Default COMPLIANCE-mode retention in days."
}

variable "lifecycle_transitions" {
  type = list(object({
    days          = number
    storage_class = string
  }))
  description = "Ordered storage-class transitions."
}

variable "enable_replication" {
  type        = bool
  description = "Enable cross-region replication."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
