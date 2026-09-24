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

variable "platform_repo" {
  type    = string
  default = "platform-infra"
}

variable "ami_repo" {
  type    = string
  default = "wordpress-ami"
}

variable "workload_repo" {
  type    = string
  default = "wordpress-infra"
}

variable "github_owner_id" {
  type = string
}

variable "platform_repo_id" {
  type = string
}

variable "ami_repo_id" {
  type = string
}

variable "workload_repo_id" {
  type = string
}
