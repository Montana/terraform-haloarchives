variable "name_prefix" {
  type        = string
  description = "Prefix for named resources."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "az_count" {
  type        = number
  description = "Number of AZs to spread subnets across."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
