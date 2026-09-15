# SSH + mosh in, everything out. Apps are reached over an SSH port-forward,
# never exposed publicly. NixOS runs its own firewall with the same rules.
resource "hcloud_firewall" "dev_box" {
  name = "dev-box"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # mosh (UDP) — worth it at ~150 ms from the US west coast
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "60000-61000"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}
