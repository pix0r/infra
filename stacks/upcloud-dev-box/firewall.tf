# UpCloud-side firewall. Trial accounts cannot run with it disabled, so keep it
# on with accept rules only. No catch-all drop: the NixOS nftables firewall on
# the box is the enforcing one (22 + mosh in, everything else dropped). Add a
# trailing drop rule here later for defence in depth.
resource "upcloud_firewall_rules" "dev_box" {
  count = var.enabled ? 1 : 0

  server_id = upcloud_server.dev_box[0].id

  firewall_rule {
    action                 = "accept"
    comment                = "SSH"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
    destination_port_start = "22"
    destination_port_end   = "22"
  }

  firewall_rule {
    action                 = "accept"
    comment                = "mosh"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "udp"
    destination_port_start = "60000"
    destination_port_end   = "61000"
  }

  firewall_rule {
    action    = "accept"
    comment   = "ICMP (ping, path MTU)"
    direction = "in"
    family    = "IPv4"
    protocol  = "icmp"
  }

  firewall_rule {
    action    = "accept"
    comment   = "all outbound"
    direction = "out"
    family    = "IPv4"
  }
}
