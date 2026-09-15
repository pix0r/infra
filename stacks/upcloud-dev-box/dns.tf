# dev.matz.io → the box. Follows the server IP through replacements (TTL 60).
resource "aws_route53_record" "dev_box" {
  count = var.enabled && var.dns_name != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "${var.dns_name}.${var.domain}"
  type    = "A"
  ttl     = 60
  records = [upcloud_server.dev_box[0].network_interface[0].ip_address]
}
