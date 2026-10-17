# Persistent state. Survives server replacement and var.enabled = false.
# Mounted at /data by hosts/dev-box/hardware.nix (by label; label set by cloud-init).
resource "upcloud_storage" "data" {
  title = "${var.hostname}-data"
  # Original disk: do not tie these to replacement defaults. Tier changes replace.
  size = 20
  tier = "maxiops"
  zone = var.zone

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

# Import the completed detached API clone before merging this stage.
# No clone block: deleting the source snapshot must not replace this disk.
resource "upcloud_storage" "data_standard" {
  title = "${var.hostname}-data-standard"
  size  = var.data_size
  tier  = var.data_tier
  zone  = var.zone

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }

  lifecycle {
    prevent_destroy = true
  }
}
