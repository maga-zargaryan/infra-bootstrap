# infra-bootstrap

One-time AWS account bootstrap for the Terraform/GitHub infrastructure repositories.

Creates only:
- S3 bucket for Terraform state
- S3 native state locking (`use_lockfile`)
- S3 server-side encryption (SSE-S3) for Terraform state
- GitHub Actions OIDC provider
- Separate GitHub OIDC IAM deployment roles for platform dev/prod, AMI, and workload dev/prod

Does **not** create application/platform resources such as VPCs, ACM, Route53, application KMS keys, VPC endpoints, EC2, RDS, or EFS.

## First-time bootstrap

1. Copy `config/bootstrap.tfvars.example` to `config/bootstrap.tfvars` and replace the placeholders.
2. Run Terraform locally with bootstrap state stored locally for the first apply:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=config/bootstrap.tfvars
terraform apply -var-file=config/bootstrap.tfvars
```

3. After the S3 bucket exists, configure the S3 backend in `terraform/backend.tf` and migrate the state:

```bash
terraform init -migrate-state
```

Do not commit account-specific `.tfvars` or backend files containing private/account-specific values.
