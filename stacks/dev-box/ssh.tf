# Authorize the GitHub user's public keys for root. cloud-init separately imports
# the same keys for the `dev` user via ssh_import_id, so no key material lives in
# this repo or in state beyond public keys.
data "http" "github_keys" {
  url = "https://github.com/${var.github_user}.keys"
}

locals {
  github_keys = compact(split("\n", trimspace(data.http.github_keys.response_body)))
}

resource "hcloud_ssh_key" "github" {
  for_each = { for k in local.github_keys : substr(sha256(k), 0, 8) => k }

  name       = "${var.github_user}-github-${each.key}"
  public_key = each.value
}
