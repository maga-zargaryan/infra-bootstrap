# The public hosted zone is never created or destroyed by Terraform: it is always
# adopted with this import block, because recreating it reissues the name servers
# and breaks delegation at the registrar.
import {
  to = aws_route53_zone.primary
  id = var.route53_zone_id
}

resource "aws_route53_zone" "primary" {
  name    = var.route53_zone_name
  comment = "Managed by Terraform"

  lifecycle {
    prevent_destroy = true
  }
}
