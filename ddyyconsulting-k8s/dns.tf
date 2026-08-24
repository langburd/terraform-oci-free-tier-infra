# Read the OCI LB public IP from the Traefik service status.
data "kubernetes_service" "traefik" {
  metadata {
    name      = helm_release.traefik.name
    namespace = local.namespaces.traefik
  }
}

locals {
  traefik_lb_ip = data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip
}

# Cloudflare zone lookup (provider v5).
data "cloudflare_zone" "this" {
  filter = { name = local.cloudflare_zone_name }
}

# Cloudflare's published edge ranges. Used for the Traefik entrypoint's trusted
# forwarded-headers list and for the Service's loadBalancerSourceRanges, so the
# origin only accepts (and only trusts XFF from) Cloudflare.
# IPv4 only: the origin NLB has no IPv6 address and the A record has no AAAA peer,
# so Cloudflare always reaches it over IPv4.
data "cloudflare_ip_ranges" "cloudflare" {}

resource "cloudflare_dns_record" "argocd" {
  zone_id = data.cloudflare_zone.this.zone_id
  name    = local.argocd_fqdn
  type    = "A"
  content = local.traefik_lb_ip
  ttl     = 1 # Proxied records must use ttl = 1 ("automatic"); Cloudflare rejects others.
  # Proxied: hides the origin IP and lets the WAF rule in waf.tf reject unwanted
  # clients at the edge. Cloudflare terminates TLS and re-originates to Traefik, so
  # the zone's SSL/TLS mode must be Full (strict) — see docs/cloudflare-tokens.md.
  # The Let's Encrypt cert is still issued via DNS-01, unaffected by proxying.
  proxied = true
}
