resource "aws_iam_role_policy" "platform_dev_state" {
  name = "terraform-state-platform-dev"
  role = aws_iam_role.github["platform_dev"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
  })
}

resource "aws_iam_role_policy" "platform_prod_state" {
  name = "terraform-state-platform-prod"
  role = aws_iam_role.github["platform_prod"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
  })
}