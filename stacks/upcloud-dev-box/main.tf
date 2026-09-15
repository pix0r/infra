# Auth: UPCLOUD_TOKEN from secrets/terraform.env (SOPS). Nothing in code.
provider "upcloud" {}

# Route 53 for the public name. AWS_* creds come from secrets/terraform.env.
provider "aws" {
  region = var.aws_region
}
