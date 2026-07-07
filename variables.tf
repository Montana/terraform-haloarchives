variable "project" {
  description = "Project slug used to prefix all resource names."
  type        = string
  default     = "haloarchives"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 3-21 chars, lowercase alphanumeric or hyphen, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "Region used for cross-region replication of the archive bucket."
  type        = string
  default     = "us-west-2"
}

variable "owner" {
  description = "Team or individual responsible for the stack (tag)."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center used for billing allocation (tag)."
  type        = string
  default     = "0000"
}

variable "additional_tags" {
  description = "Extra tags merged into the default tag set."
  type        = map(string)
  default     = {}
}

# ---------- Networking ----------
variable "vpc_cidr" {
  description = "CIDR block for the platform VPC."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread private subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

# ---------- Storage / lifecycle ----------
variable "enable_object_lock" {
  description = "Enable S3 Object Lock (WORM). Cannot be toggled off after bucket creation."
  type        = bool
  default     = true
}

variable "object_lock_retention_days" {
  description = "Default compliance-mode retention window for archived objects."
  type        = number
  default     = 3650 # ~10 years
}

variable "lifecycle_transitions" {
  description = "Ordered storage-class transitions applied to archived objects."
  type = list(object({
    days          = number
    storage_class = string
  }))
  default = [
    { days = 30, storage_class = "STANDARD_IA" },
    { days = 90, storage_class = "GLACIER" },
    { days = 365, storage_class = "DEEP_ARCHIVE" },
  ]
}

variable "enable_replication" {
  description = "Replicate the archive bucket to replica_region for durability/DR."
  type        = bool
  default     = false
}

# ---------- Catalog ----------
variable "catalog_billing_mode" {
  description = "DynamoDB billing mode for the catalog table."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.catalog_billing_mode)
    error_message = "catalog_billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "catalog_point_in_time_recovery" {
  description = "Enable PITR on the catalog table."
  type        = bool
  default     = true
}

# ---------- Compute ----------
variable "lambda_runtime" {
  description = "Runtime for all platform Lambda functions."
  type        = string
  default     = "python3.12"
}

variable "lambda_architecture" {
  description = "Lambda CPU architecture."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be arm64 or x86_64."
  }
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for Lambda log groups."
  type        = number
  default     = 30
}

# ---------- Observability ----------
variable "alarm_sns_email" {
  description = "Email subscribed to the CloudWatch alarm topic. Empty disables the subscription."
  type        = string
  default     = ""
}

variable "ingestion_dlq_alarm_threshold" {
  description = "DLQ visible-message count that trips the ingestion alarm."
  type        = number
  default     = 1
}
