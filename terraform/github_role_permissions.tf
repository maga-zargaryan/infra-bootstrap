locals {
  terraform_state_bucket_actions = [
    "s3:ListBucket",
    "s3:GetBucketVersioning"
  ]

  terraform_state_object_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ]
}

resource "aws_iam_role_policy" "ami_state" {
  name = "terraform-state-java-ami"
  role = aws_iam_role.github["ami"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = local.terraform_state_bucket_actions
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = local.terraform_state_object_actions

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/ami/java/terraform.tfstate",
          "${aws_s3_bucket.terraform_state.arn}/ami/java/terraform.tfstate.tflock"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "workload_dev_state" {
  name = "terraform-state-workload-dev"
  role = aws_iam_role.github["workload_dev"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = local.terraform_state_bucket_actions
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = local.terraform_state_object_actions

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/workload/dev/terraform.tfstate",
          "${aws_s3_bucket.terraform_state.arn}/workload/dev/terraform.tfstate.tflock"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "workload_prod_state" {
  name = "terraform-state-workload-prod"
  role = aws_iam_role.github["workload_prod"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = local.terraform_state_bucket_actions
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = local.terraform_state_object_actions

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/workload/prod/terraform.tfstate",
          "${aws_s3_bucket.terraform_state.arn}/workload/prod/terraform.tfstate.tflock"
        ]
      }
    ]
  })
}