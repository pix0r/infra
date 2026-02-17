provider "hcloud" {
  token = var.hcloud_token
}

provider "aws" {
  region = var.aws_region
  # Credentials via AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars
  # or ~/.aws/credentials profile
}
