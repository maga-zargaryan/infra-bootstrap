# GitHub delivery controls as code: environments, their AWS role bindings and
# main-branch protection. Hand-made changes in the GitHub UI are reverted on apply.

locals {
  github_environments = {
    for k, v in local.ci_roles : "${v.repo}/${v.environment}" => {
      repository  = var.repositories[v.repo].name
      repo_key    = v.repo
      environment = v.environment
      role_arn    = aws_iam_role.github[k].arn
      access      = v.access
    }
  }

  # Environment variables published to every pipeline environment.
  github_environment_variables = merge([
    for key, env in local.github_environments : {
      "${key}/AWS_ROLE_ARN" = { env_key = key, name = "AWS_ROLE_ARN", value = env.role_arn }
      "${key}/AWS_REGION"   = { env_key = key, name = "AWS_REGION", value = var.aws_region }
    }
  ]...)

  # Environments and variables created by hand before this was managed as code.
  preexisting_environments = toset([
    "platform/development", "platform/development-plan",
    "platform/production", "platform/production-plan",
    "platform/shared", "platform/shared-plan",
    "workload/development", "workload/development-plan",
    "workload/production", "workload/production-plan",
  ])

  preexisting_variables = toset(flatten([
    for key in local.preexisting_environments : ["${key}/AWS_ROLE_ARN", "${key}/AWS_REGION"]
  ]))
}

resource "github_repository_environment" "this" {
  for_each = local.github_environments

  repository  = each.value.repository
  environment = each.value.environment

  # Production deployments wait for an explicit approval.
  dynamic "reviewers" {
    for_each = each.value.environment == "production" ? [1] : []

    content {
      users = var.github_reviewer_ids
    }
  }

  # Apply environments only accept deployments from protected branches (main);
  # plan environments must stay open to pull-request branches.
  dynamic "deployment_branch_policy" {
    for_each = each.value.access == "apply" ? [1] : []

    content {
      protected_branches     = true
      custom_branch_policies = false
    }
  }
}

import {
  for_each = local.preexisting_environments

  to = github_repository_environment.this[each.value]
  id = "${local.github_environments[each.value].repository}:${local.github_environments[each.value].environment}"
}

resource "github_actions_environment_variable" "this" {
  for_each = local.github_environment_variables

  repository    = github_repository_environment.this[each.value.env_key].repository
  environment   = github_repository_environment.this[each.value.env_key].environment
  variable_name = each.value.name
  value         = each.value.value
}

import {
  for_each = local.preexisting_variables

  to = github_actions_environment_variable.this[each.value]
  id = "${local.github_environments[local.github_environment_variables[each.value].env_key].repository}:${local.github_environments[local.github_environment_variables[each.value].env_key].environment}:${local.github_environment_variables[each.value].name}"
}

# Alarm subscriptions in java-infra; a secret so it is masked in public workflow logs.
resource "github_actions_environment_secret" "alert_email" {
  for_each = { for k, v in local.github_environments : k => v if v.repo_key == "workload" }

  repository  = github_repository_environment.this[each.key].repository
  environment = github_repository_environment.this[each.key].environment
  secret_name = "ALERT_EMAIL"
  value       = var.alert_email
}

resource "github_branch_protection" "main" {
  for_each = var.protected_repositories

  repository_id                   = var.repositories[each.value].name
  pattern                         = "main"
  enforce_admins                  = true
  require_conversation_resolution = true
  allows_force_pushes             = false
  allows_deletions                = false

  required_status_checks {
    strict   = true
    contexts = ["ci"]
  }

  # Single maintainer: a pull request is required, but GitHub does not allow
  # self-approval, so the approval count is 0. Raise to 1 with a second maintainer.
  required_pull_request_reviews {
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
  }
}

# Encrypts saved production plans uploaded as workflow artifacts (public repositories).
resource "random_password" "plan_passphrase" {
  length  = 48
  special = false
}

resource "github_actions_secret" "plan_passphrase" {
  for_each = toset(["platform", "workload"])

  repository  = var.repositories[each.value].name
  secret_name = "TF_PLAN_PASSPHRASE"
  value       = random_password.plan_passphrase.result
}
