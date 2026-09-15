# Mike's keys (public) — root on the fresh template and the NixOS config both use them.
data "http" "github_keys" {
  url = "https://github.com/${var.github_user}.keys"
}

locals {
  github_keys = compact(split("\n", trimspace(data.http.github_keys.response_body)))
}

# CI bootstrap key: lets the deploy job run nixos-anywhere against the fresh
# template. Lives in state (S3) like the hetzner-primary key does. After install,
# root is reachable only with the GitHub keys above.
resource "tls_private_key" "bootstrap" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "bootstrap_key" {
  content         = tls_private_key.bootstrap.private_key_openssh
  filename        = "${path.module}/.ssh/bootstrap_ed25519"
  file_permission = "0600"
}
