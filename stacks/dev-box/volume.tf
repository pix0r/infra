# Persistent state. Survives server replacement and var.enabled = false.
# Mounted at /data by hosts/dev-box/hardware.nix (by filesystem label, set in cloud-init).
resource "hcloud_volume" "data" {
  name     = "${var.server_name}-data"
  size     = var.volume_size
  location = var.server_location
  format   = "ext4"

  delete_protection = true

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_volume_attachment" "data" {
  count = var.enabled ? 1 : 0

  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.dev_box[0].id
  automount = false
}
