# Account-level values consumed by platform-infra, java-ami and java-infra.
locals {
  published_parameters = {
    "route53_zone_id"   = aws_route53_zone.primary.zone_id
    "route53_zone_name" = aws_route53_zone.primary.name
    "artifacts_bucket"  = module.artifacts_bucket.id
    "boundary_arn"      = aws_iam_policy.workload_boundary.arn
  }
}

resource "aws_ssm_parameter" "published" {
  for_each = local.published_parameters

  name  = "/java-platform/${each.key}"
  type  = "String"
  value = each.value
}
