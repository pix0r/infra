# Wildcard for app subdomains. Also covers app.matz.io (orchestrator admin UI).
resource "aws_route53_record" "apps_wildcard" {
  zone_id = var.route53_zone_id
  name    = local.apps_fqdn
  type    = "A"
  ttl     = 300
  records = [hcloud_server.primary.ipv4_address]
}

# Publish-slice subdomain — separate auth posture from apps.* (admin).
# TENTATIVE: Mike may unify on share.pixor.net in Sprint 4; revisit then.
resource "aws_route53_record" "share" {
  zone_id = var.route53_zone_id
  name    = local.share_fqdn
  type    = "A"
  ttl     = 300
  records = [hcloud_server.primary.ipv4_address]
}
