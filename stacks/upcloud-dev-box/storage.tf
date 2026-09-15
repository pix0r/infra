# Persistent state. Survives server replacement and var.enabled = false.
# Mounted at /data by hosts/dev-box/hardware.nix (by label; label set by cloud-init).
resource "upcloud_storage" "data" {
  title = "${var.hostname}-data"
  size  = var.data_size
  tier  = var.data_tier
  zone  = var.zone

  backup_rule {
    interval  = "daily"
    time      = "0900" # 09:00 UTC = 02:00 Pacific
    retention = 7
  }

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }

  lifecycle {
    prevent_destroy = true
  }
}
