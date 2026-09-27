# infra-bootstrap

One-time AWS account bootstrap for the Terraform/GitHub infrastructure repositories.

Creates only:
- S3 bucket for Terraform state, versioning, SSE-S3 and native S3 locking support
- GitHub Actions OIDC provider
- Separate OIDC roles for platform dev/prod-plan/prod, shared platform infrastructure, Java AMI, and Java workload deployment

Does not create VPCs, subnets, endpoints, ACM, Route53, EC2, RDS, EFS, or Image Builder resources.

## Repository roles

- `github-actions-platform_dev` -> `platform/dev/terraform.tfstate`
- `github-actions-platform_prod_plan` -> `platform/prod/terraform.tfstate` (plan only)
- `github-actions-platform_prod` -> `platform/prod/terraform.tfstate` (apply)
- `github-actions-platform_shared` -> `platform/shared/terraform.tfstate`
- `github-actions-ami` -> Java AMI repository state
- `github-actions-workload_dev` -> Java workload repository `development` environment
- `github-actions-workload_prod` -> Java workload repository `production` environment

The shared platform role is branch-bound to `main`; it is deliberately not a GitHub Environment.

## First-time bootstrap

Copy `config/bootstrap.tfvars.example` to `config/bootstrap.tfvars`, fill the real GitHub numeric IDs, and apply the bootstrap. The account-specific tfvars file must not be committed.
