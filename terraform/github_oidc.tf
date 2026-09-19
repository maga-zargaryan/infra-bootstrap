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
    platform_dev  = var.platform_repo
    platform_prod = var.platform_repo
    ami           = var.ami_repo
    workload_dev  = var.workload_repo
    workload_prod = var.workload_repo
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
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${each.value}:ref:refs/heads/main"
          ]
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
