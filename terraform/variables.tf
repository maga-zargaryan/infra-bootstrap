variable "aws_region" {
  description = "AWS region for the bootstrap resources."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user that owns the infrastructure repositories."
  type        = string
}

variable "github_owner_id" {
  description = "Immutable numeric ID of the GitHub owner."
  type        = string
}

variable "github_reviewer_ids" {
  description = "Numeric GitHub user IDs allowed to approve production deployments."
  type        = list(number)
}

variable "repositories" {
  description = "Infrastructure repositories, keyed by logical name. id is the immutable numeric GitHub repository ID."
  type = map(object({
    name = string
    id   = string
  }))

  validation {
    condition     = alltrue([for k in ["bootstrap", "platform", "ami", "workload", "app"] : contains(keys(var.repositories), k)])
    error_message = "repositories must define bootstrap, platform, ami, workload and app."
  }
}

variable "protected_repositories" {
  description = "Logical repository names whose main branch is protected. A repository must have a main branch before it can be listed."
  type        = set(string)
}

variable "route53_zone_name" {
  description = "Public hosted zone that already exists and is always imported, never created."
  type        = string
}

variable "route53_zone_id" {
  description = "ID of the existing public hosted zone."
  type        = string
}

variable "alert_email" {
  description = "Email address for budget and alarm notifications."
  type        = string
  sensitive   = true
}

variable "budget_name" {
  description = "Name of the existing monthly cost budget."
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly cost budget limit in USD."
  type        = string
}

variable "production_enabled" {
  description = "Whether pipelines plan and deploy production. False keeps production stages skipped."
  type        = bool
}

variable "cloudtrail_kms_enabled" {
  description = "Encrypt CloudTrail logs with a customer-managed KMS key ($1/month). False uses SSE-S3 and schedules the key for deletion."
  type        = bool
  default     = true
}

variable "release_app_id" {
  description = "ID of the release GitHub App that opens cross-repository pull requests. null until the app exists."
  type        = number
  default     = null
}
