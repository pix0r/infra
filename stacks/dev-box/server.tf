resource "hcloud_server" "dev_box" {
  count = var.enabled ? 1 : 0

  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image

  ssh_keys     = [for k in hcloud_ssh_key.github : k.id]
  firewall_ids = [hcloud_firewall.dev_box.id]

  # Ubuntu boots, cloud-init labels the data volume and runs nixos-infect, the box
  # reboots into NixOS, a one-shot unit switches to var.flake_ref, reboots again,
  # and from then on comin (services.comin in the flake) keeps it on main.
  user_data = templatefile("${path.module}/cloud-init/dev-box.yaml", {
    volume_id        = hcloud_volume.data.id
    nixos_channel    = var.nixos_channel
    nixos_infect_ref = var.nixos_infect_ref
    flake_ref        = var.flake_ref
  })

  public_net {
    ipv4_enabled = true
    # No IPv6 on purpose: nixos-infect would need a static v6 config that the
    # flake does not carry. IPv4 is DHCP on Hetzner Cloud, so the flake stays generic.
    ipv6_enabled = false
  }

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }

  # user_data is intentionally NOT ignored: a cloud-init change replaces the
  # server. State lives on the data volume, so a replacement costs only the
  # Claude/gh logins. The plan says "must be replaced" — read it before merging.
}
