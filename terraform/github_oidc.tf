resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  # One role per repository and GitHub Environment. "plan" roles are read-only
  # and used on pull requests; "apply" roles are bound to protected environments.
  ci_roles = {
    platform_dev         = { repo = "platform", environment = "development", access = "apply", state_key = "platform/dev" }
    platform_dev_plan    = { repo = "platform", environment = "development-plan", access = "plan", state_key = "platform/dev" }
    platform_prod        = { repo = "platform", environment = "production", access = "apply", state_key = "platform/prod" }
    platform_prod_plan   = { repo = "platform", environment = "production-plan", access = "plan", state_key = "platform/prod" }
    platform_shared      = { repo = "platform", environment = "shared", access = "apply", state_key = "platform/shared" }
    platform_shared_plan = { repo = "platform", environment = "shared-plan", access = "plan", state_key = "platform/shared" }
    ami                  = { repo = "ami", environment = "shared", access = "apply", state_key = "ami/java" }
    ami_plan             = { repo = "ami", environment = "shared-plan", access = "plan", state_key = "ami/java" }
    workload_dev         = { repo = "workload", environment = "development", access = "apply", state_key = "workload/dev" }
    workload_dev_plan    = { repo = "workload", environment = "development-plan", access = "plan", state_key = "workload/dev" }
    workload_prod        = { repo = "workload", environment = "production", access = "apply", state_key = "workload/prod" }
    workload_prod_plan   = { repo = "workload", environment = "production-plan", access = "plan", state_key = "workload/prod" }
  }

  apply_roles = { for k, v in local.ci_roles : k => v if v.access == "apply" }
}

data "aws_iam_policy_document" "ci_trust" {
  for_each = local.ci_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Immutable owner/repository IDs prevent takeover through a renamed or recreated repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.repositories[each.value.repo].name}@${var.repositories[each.value.repo].id}:environment:${each.value.environment}"
      ]
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.ci_roles

  name                 = "github-actions-${each.key}"
  description          = "GitHub Actions ${each.value.access} role for ${var.repositories[each.value.repo].name} (${each.value.environment})"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust[each.key].json
  max_session_duration = 3600

  tags = {
    Repository  = var.repositories[each.value.repo].name
    Environment = each.value.environment
    Access      = each.value.access
  }
}

# Every role reads everything; writes are granted per repository below.
resource "aws_iam_role_policy_attachment" "read_only" {
  for_each = local.ci_roles

  role       = aws_iam_role.github[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "state_access" {
  for_each = local.ci_roles

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [module.state_bucket.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${module.state_bucket.arn}/${each.value.state_key}/terraform.tfstate"]
  }

  # Plan roles still take the lock so a plan never races an apply.
  statement {
    sid       = "ManageLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.state_bucket.arn}/${each.value.state_key}/terraform.tfstate.tflock"]
  }

  dynamic "statement" {
    for_each = each.value.access == "apply" ? [1] : []

    content {
      sid       = "WriteState"
      actions   = ["s3:PutObject"]
      resources = ["${module.state_bucket.arn}/${each.value.state_key}/terraform.tfstate"]
    }
  }
}

resource "aws_iam_role_policy" "state_access" {
  for_each = local.ci_roles

  name   = "terraform-state"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.state_access[each.key].json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = local.apply_roles

  role       = aws_iam_role.github[each.key].name
  policy_arn = aws_iam_policy.deploy[each.value.repo].arn
}
