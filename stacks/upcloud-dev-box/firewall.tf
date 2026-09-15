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

  # UpCloud's firewall is NOT stateful for UDP: outbound queries leave, the
  # replies get dropped unless explicitly accepted. Without these, DNS (and
  # NTP) silently fail even though TCP works. Verified 2026-09-15.
  firewall_rule {
    action            = "accept"
    comment           = "DNS replies (UDP, stateless firewall)"
    direction         = "in"
    family            = "IPv4"
    protocol          = "udp"
    source_port_start = "53"
    source_port_end   = "53"
  }

  firewall_rule {
    action            = "accept"
    comment           = "NTP replies (UDP, stateless firewall)"
    direction         = "in"
    family            = "IPv4"
    protocol          = "udp"
    source_port_start = "123"
    source_port_end   = "123"
  }

  firewall_rule {
    action    = "accept"
    comment   = "all outbound"
    direction = "out"
    family    = "IPv4"
  }
}
