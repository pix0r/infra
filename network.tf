# Private network for inter-server communication (future multi-node)
resource "hcloud_network" "main" {
  name     = "main"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "servers" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "us-east"
  ip_range     = "10.0.1.0/24"
}

# Firewall: only allow SSH, HTTP, HTTPS inbound
resource "hcloud_firewall" "default" {
  name = "default"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
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
