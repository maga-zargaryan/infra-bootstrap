data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

locals {
  role_repos = {
    platform_dev  = {
      repo    = var.platform_repo
      repo_id = var.platform_repo_id
      env     = "development"
    }

    platform_prod_plan = {
      repo    = var.platform_repo
      repo_id = var.platform_repo_id
      env     = "production-plan"
    }

    platform_prod = {
      repo    = var.platform_repo
      repo_id = var.platform_repo_id
      env     = "production"
    }

    ami = {
      repo    = var.ami_repo
      repo_id = var.ami_repo_id
      env     = null
    }
    workload_dev = {
      repo    = var.workload_repo
      repo_id = var.workload_repo_id
      env     = null
    }
    workload_prod = {
      repo    = var.workload_repo
      repo_id = var.workload_repo_id
      env     = null
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.role_repos

  name = "github-actions-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = (
          each.value.env != null
          ? "repo:${var.github_org}@${var.github_owner_id}/${each.value.repo}@${each.value.repo_id}:environment:${each.value.env}"
          : "repo:${var.github_org}@${var.github_owner_id}/${each.value.repo}@${each.value.repo_id}:ref:refs/heads/main"
          )
        }
      }
    }]
  })

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "GitHub Actions OIDC"
  }
}

# Bootstrap intentionally grants no platform/application permissions.
# Each downstream repository owns the permissions attached to its deployment role.
