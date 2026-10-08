# Private store for reviewed production plans. The prod plan job writes
# <repo>/prod/<run id>/tfplan, the prod apply job reads and deletes it after the
# apply; a lifecycle rule removes anything left behind (e.g. a rejected approval)
# after one day. Plans contain state values, so only those two roles may touch them.

locals {
  plan_store_repos = {
    platform = { plan_role = "platform_prod_plan", apply_role = "platform_prod" }
    workload = { plan_role = "workload_prod_plan", apply_role = "workload_prod" }
  }
}

data "aws_iam_policy_document" "plan_store_bucket" {
  dynamic "statement" {
    for_each = local.plan_store_repos

    content {
      sid       = "OnlyProdRoles${title(statement.key)}"
      effect    = "Deny"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = ["arn:${local.partition}:s3:::tfplans-${local.account_id}-${var.aws_region}/${var.repositories[statement.key].name}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "ArnNotEquals"
        variable = "aws:PrincipalArn"
        values = [
          aws_iam_role.github[statement.value.plan_role].arn,
          aws_iam_role.github[statement.value.apply_role].arn,
        ]
      }
    }
  }
}

module "plan_store" {
  source = "./modules/secure-bucket"

  name                               = "tfplans-${local.account_id}-${var.aws_region}"
  current_version_expiration_days    = 1
  noncurrent_version_expiration_days = 1
  additional_policy_json             = data.aws_iam_policy_document.plan_store_bucket.json
}

resource "aws_iam_role_policy" "plan_store_write" {
  for_each = local.plan_store_repos

  name = "prod-plan-store"
  role = aws_iam_role.github[each.value.plan_role].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "StorePlan"
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${module.plan_store.arn}/${var.repositories[each.key].name}/prod/*"
    }]
  })
}

resource "aws_iam_role_policy" "plan_store_read" {
  for_each = local.plan_store_repos

  name = "prod-plan-store"
  role = aws_iam_role.github[each.value.apply_role].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "FetchAndDeletePlan"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:DeleteObject"]
      Resource = "${module.plan_store.arn}/${var.repositories[each.key].name}/prod/*"
    }]
  })
}

resource "github_actions_variable" "plan_bucket" {
  for_each = local.plan_store_repos

  repository    = var.repositories[each.key].name
  variable_name = "TF_PLAN_BUCKET"
  value         = module.plan_store.id
}
