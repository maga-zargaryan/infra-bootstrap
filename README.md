# infra-bootstrap

Long-lived account foundation for the Java platform. Applied **locally by an
administrator**, because it creates the roles every other pipeline uses. Nothing
here is torn down when environments are destroyed.

```text
infra-bootstrap ─► platform-infra ─► java-ami ─► java-infra
```

## What it manages

| Area | Resources |
|---|---|
| Terraform state | S3 bucket (versioned, SSE, TLS-only, `prevent_destroy`), native S3 locking |
| Release artifacts | `java-platform-artifacts-<account>-<region>`, versioned JARs under `java-app/<version>/` |
| CI identity | GitHub OIDC provider, one role per repository × GitHub Environment |
| Guardrails | `java-platform-permissions-boundary`, required on every IAM role a pipeline creates |
| Account baseline | EBS encryption by default, S3 account public access block, IAM Access Analyzer, multi-region CloudTrail |
| DNS | Public hosted zone, **always imported, never created** (`prevent_destroy`) |
| Cost | Monthly budget with email alerts (imported) |
| GitHub | Environments, required reviewers, `AWS_ROLE_ARN`/`AWS_REGION` variables, `ALERT_EMAIL` secret, `main` branch protection |

Values other repositories need are published to SSM Parameter Store under `/java-platform/`.

## CI roles

| Repository | Environment | Role | Access |
|---|---|---|---|
| platform-infra | `development` / `production` / `shared` | `github-actions-platform_{dev,prod,shared}` | apply |
| platform-infra | `*-plan` | `github-actions-platform_*_plan` | read-only |
| java-ami | `shared` / `shared-plan` | `github-actions-ami[_plan]` | apply / read-only |
| java-infra | `development` / `production` | `github-actions-workload_{dev,prod}` | apply |
| java-infra | `*-plan` | `github-actions-workload_*_plan` | read-only |

- Trust is pinned to the immutable owner and repository IDs and the GitHub Environment (`StringEquals`).
- Plan roles: `ReadOnlyAccess` + read of their own state + lock file.
- Apply roles: `ReadOnlyAccess` + a per-repository write policy (`github-actions-deploy-*`).
  They can only create IAM roles under their own name prefix and only with the permissions boundary attached.
- Apply environments accept deployments from `main` only; `production` requires approval.

## Apply

```bash
export GITHUB_TOKEN=$(gh auth token)
cd terraform
terraform init
terraform plan  -var-file=../config/bootstrap.tfvars -out=tfplan
terraform apply tfplan
```

`config/bootstrap.tfvars` is not committed (it holds the alert email); start from
`config/bootstrap.tfvars.example`. A repository must have a `main` branch before it
is added to `protected_repositories`.

### First-time bootstrap in a new account

1. Comment out `backend.tf`, apply with local state to create the state bucket.
2. Restore `backend.tf` and run `terraform init -migrate-state`.

## Single account

Everything runs in one AWS account, isolated by VPC, KMS key, IAM role and state
file per environment. The full Well-Architected setup is one account per
environment under AWS Organizations; the code is account-agnostic so that move
only changes configuration.
