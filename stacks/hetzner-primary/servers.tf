resource "hcloud_server" "primary" {
  name        = "primary"
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image

  ssh_keys = [hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.default.id]

  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.2"
  }

  user_data = templatefile("${path.module}/cloud-init/primary.yaml", {
    flux_github_pat = var.flux_github_pat
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  depends_on = [hcloud_network_subnet.servers]

  lifecycle {
    ignore_changes = [user_data]
  }
}
