data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

module "state_bucket" {
  source = "./modules/secure-bucket"

  name = var.state_bucket_name
}

moved {
  from = aws_s3_bucket.terraform_state
  to   = module.state_bucket.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_versioning.terraform_state
  to   = module.state_bucket.aws_s3_bucket_versioning.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.terraform_state
  to   = module.state_bucket.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.terraform_state
  to   = module.state_bucket.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.terraform_state
  to   = module.state_bucket.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.terraform_state
  to   = module.state_bucket.aws_s3_bucket_lifecycle_configuration.this
}

# Versioned application releases (java-app/<version>/app.jar), shared by dev and prod
# so the same artifact is promoted between environments.
module "artifacts_bucket" {
  source = "./modules/secure-bucket"

  name = "java-platform-artifacts-${local.account_id}-${var.aws_region}"
}
