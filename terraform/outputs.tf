output "state_bucket_name" {
  value = module.state_bucket.id
}

output "artifacts_bucket_name" {
  value = module.artifacts_bucket.id
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_role_arns" {
  value = { for name, role in aws_iam_role.github : name => role.arn }
}

output "permissions_boundary_arn" {
  value = aws_iam_policy.workload_boundary.arn
}

output "route53_zone_id" {
  value = aws_route53_zone.primary.zone_id
}

output "plan_store_bucket_name" {
  value = module.plan_store.id
}
