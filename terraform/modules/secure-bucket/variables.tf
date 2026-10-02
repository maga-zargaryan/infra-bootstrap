variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions are deleted."
  type        = number
  default     = 90
}

variable "current_version_expiration_days" {
  description = "Days after which current object versions expire. null keeps them indefinitely."
  type        = number
  default     = null
}

variable "additional_policy_json" {
  description = "Extra bucket policy statements merged with the TLS-only baseline."
  type        = string
  default     = null
}
