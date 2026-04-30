# Root-level globals shared across all stacks
globals {
  domain          = "matz.io"
  coolify_fqdn    = "deploy.matz.io"
  forgejo_fqdn    = "dev.matz.io"
  apps_wildcard   = "*.app.matz.io"
  server_type     = "cax31"
  server_location = "ash"
  server_image    = "ubuntu-24.04"
  aws_region      = "us-east-1"
  tfstate_bucket  = "matz-infra-tfstate"
}
