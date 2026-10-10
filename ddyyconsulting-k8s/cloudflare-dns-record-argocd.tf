resource "cloudflare_dns_record" "argocd" {
  content = local.traefik_lb_ip
  name    = local.argocd_fqdn
  # Proxied: hides the origin IP and lets the WAF rule in waf.tf reject unwanted
  # clients at the edge. Cloudflare terminates TLS and re-originates to Traefik, so
  # the zone's SSL/TLS mode must be Full (strict) — see docs/cloudflare-tokens.md.
  # The Let's Encrypt cert is still issued via DNS-01, unaffected by proxying.
  proxied = true
  ttl     = 1 # Proxied records must use ttl = 1 ("automatic"); Cloudflare rejects others.
  type    = "A"
  zone_id = data.cloudflare_zone.this.zone_id
}
