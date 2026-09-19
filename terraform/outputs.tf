output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_role_arns" {
  value = { for name, role in aws_iam_role.github : name => role.arn }
}
