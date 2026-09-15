resource "hcloud_server" "dev_box" {
  count = var.enabled ? 1 : 0

  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image

  ssh_keys     = [for k in hcloud_ssh_key.github : k.id]
  firewall_ids = [hcloud_firewall.dev_box.id]

  user_data = templatefile("${path.module}/cloud-init/dev-box.yaml", {
    github_user         = var.github_user
    claude_code_version = var.claude_code_version
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }

  lifecycle {
    # cloud-init runs once at first boot; editing the template must not replace a live box.
    ignore_changes = [user_data]
  }
}
