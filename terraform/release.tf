# Application releases: java-app publishes tagged releases to the artifacts
# bucket from its "release" GitHub Environment. The role can only write new
# objects under java-app/ and read the bucket name; it cannot deploy anything.

data "aws_iam_policy_document" "release_trust" {
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

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.repositories["app"].name}@${var.repositories["app"].id}:environment:release"
      ]
    }
  }
}

resource "aws_iam_role" "app_release" {
  name                 = "github-actions-app_release"
  description          = "GitHub Actions release role for ${var.repositories["app"].name} (release)"
  assume_role_policy   = data.aws_iam_policy_document.release_trust.json
  max_session_duration = 3600

  tags = {
    Repository  = var.repositories["app"].name
    Environment = "release"
    Access      = "release"
  }
}

data "aws_iam_policy_document" "app_release" {
  statement {
    sid       = "FindArtifactsBucket"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.published["artifacts_bucket"].arn]
  }

  # HeadObject (GetObject) lets the pipeline refuse to overwrite an existing release.
  statement {
    sid       = "PublishReleases"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${module.artifacts_bucket.arn}/java-app/*"]
  }

  statement {
    sid       = "ListReleases"
    actions   = ["s3:ListBucket"]
    resources = [module.artifacts_bucket.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["java-app/*"]
    }
  }
}

resource "aws_iam_role_policy" "app_release" {
  name   = "publish-releases"
  role   = aws_iam_role.app_release.id
  policy = data.aws_iam_policy_document.app_release.json
}

# Only version tags (v*) can deploy to the release environment.
resource "github_repository_environment" "app_release" {
  repository  = var.repositories["app"].name
  environment = "release"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "app_release_tags" {
  repository  = github_repository_environment.app_release.repository
  environment = github_repository_environment.app_release.environment
  tag_pattern = "v*"
}

resource "github_actions_environment_variable" "app_release" {
  for_each = {
    AWS_ROLE_ARN = aws_iam_role.app_release.arn
    AWS_REGION   = var.aws_region
  }

  repository    = github_repository_environment.app_release.repository
  environment   = github_repository_environment.app_release.environment
  variable_name = each.key
  value         = each.value
}

# The release GitHub App opens the cross-repository pull requests (java-app → java-ami,
# java-ami → java-infra, java-infra promote). Its private key is set per repository with
# `gh secret set RELEASE_APP_PRIVATE_KEY` so it never lands in Terraform state.
resource "github_actions_variable" "release_app_id" {
  for_each = var.release_app_id == null ? toset([]) : toset(["app", "ami", "workload"])

  repository    = var.repositories[each.value].name
  variable_name = "RELEASE_APP_ID"
  value         = tostring(var.release_app_id)
}
