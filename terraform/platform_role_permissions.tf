locals {
  platform_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "ec2:*"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:DeleteCertificate",
        "acm:ListTagsForCertificate",
        "acm:AddTagsToCertificate"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets",
        "route53:GetHostedZone",
        "route53:GetChange",
        "route53:ListHostedZonesByName"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:EnableKeyRotation",
        "kms:DisableKeyRotation",
        "kms:GetKeyRotationStatus",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ListResourceTags",
        "kms:PutKeyPolicy",
        "kms:GetKeyPolicy",
        "kms:ListAliases"
      ]
      Resource = "*"
    }
  ]
}

# ---------------------------------------------------------
# Development
# ---------------------------------------------------------

resource "aws_iam_role_policy" "platform_dev" {
  name = "platform-infra-dev"
  role = aws_iam_role.github["platform_dev"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.platform_policy_statements,
      [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketVersioning"
          ]
          Resource = aws_s3_bucket.terraform_state.arn
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "${aws_s3_bucket.terraform_state.arn}/platform/dev/terraform.tfstate",
            "${aws_s3_bucket.terraform_state.arn}/platform/dev/terraform.tfstate.tflock"
          ]
        }
      ]
    )
  })
}

# ---------------------------------------------------------
# Production Plan
# ---------------------------------------------------------

resource "aws_iam_role_policy" "platform_prod_plan" {
  name = "platform-infra-prod-plan"
  role = aws_iam_role.github["platform_prod_plan"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.platform_policy_statements,
      [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketVersioning"
          ]
          Resource = aws_s3_bucket.terraform_state.arn
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "${aws_s3_bucket.terraform_state.arn}/platform/prod/terraform.tfstate",
            "${aws_s3_bucket.terraform_state.arn}/platform/prod/terraform.tfstate.tflock"
          ]
        }
      ]
    )
  })
}

# ---------------------------------------------------------
# Production Apply
# ---------------------------------------------------------

resource "aws_iam_role_policy" "platform_prod" {
  name = "platform-infra-prod"
  role = aws_iam_role.github["platform_prod"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.platform_policy_statements,
      [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketVersioning"
          ]
          Resource = aws_s3_bucket.terraform_state.arn
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "${aws_s3_bucket.terraform_state.arn}/platform/prod/terraform.tfstate",
            "${aws_s3_bucket.terraform_state.arn}/platform/prod/terraform.tfstate.tflock"
          ]
        }
      ]
    )
  })
}