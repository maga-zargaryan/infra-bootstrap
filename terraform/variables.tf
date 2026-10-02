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
    condition     = alltrue([for k in ["bootstrap", "platform", "ami", "workload"] : contains(keys(var.repositories), k)])
    error_message = "repositories must define bootstrap, platform, ami and workload."
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
