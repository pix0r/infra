resource "upcloud_server" "dev_box" {
  count = var.enabled ? 1 : 0

  hostname = var.hostname
  title    = var.hostname
  zone     = var.zone
  plan     = var.plan
  metadata = true  # required for cloud-init user_data on current templates
  firewall = false # NixOS nftables firewall is the one in charge (22 + mosh only)

  template {
    storage = var.template
    size    = var.root_size
    address = "virtio" # /dev/vda — matches hosts/dev-box/disko.nix
  }

  storage_devices {
    storage = upcloud_storage.data.id
    address = "virtio" # /dev/vdb on first boot; mounted by label thereafter
  }

  network_interface {
    type              = "public"
    ip_address_family = "IPv4"
  }

  login {
    user            = "root"
    keys            = concat(local.github_keys, [tls_private_key.bootstrap.public_key_openssh])
    create_password = false
  }

  # Runs once on the Ubuntu template: labels the /data volume. NixOS install
  # follows from CI (bootstrap.tf). Any change here replaces the server.
  user_data = file("${path.module}/cloud-init/dev-box.yaml")

  labels = {
    role       = "dev-box"
    managed_by = "tofu"
  }
}
