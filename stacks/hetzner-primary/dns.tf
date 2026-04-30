# Coolify dashboard
resource "aws_route53_record" "coolify" {
  zone_id = var.route53_zone_id
  name    = local.coolify_fqdn
  type    = "A"
  ttl     = 300
  records = [hcloud_server.primary.ipv4_address]
}

# Forgejo git hosting
resource "aws_route53_record" "forgejo" {
  zone_id = var.route53_zone_id
  name    = local.forgejo_fqdn
  type    = "A"
  ttl     = 300
  records = [hcloud_server.primary.ipv4_address]
}

# Wildcard for deployed apps
resource "aws_route53_record" "apps_wildcard" {
  zone_id = var.route53_zone_id
  name    = local.apps_fqdn
  type    = "A"
  ttl     = 300
  records = [hcloud_server.primary.ipv4_address]
}
