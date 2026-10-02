provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "java-platform"
      Layer      = "bootstrap"
      Repository = "infra-bootstrap"
      ManagedBy  = "terraform"
    }
  }
}

# Authenticates with the GITHUB_TOKEN environment variable:
#   export GITHUB_TOKEN=$(gh auth token)
provider "github" {
  owner = var.github_org
}
