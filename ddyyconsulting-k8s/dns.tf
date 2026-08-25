# Read the OCI LB public IP from the Traefik service status.
data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = helm_release.traefik.name
    namespace = local.namespaces.traefik
  }
}

locals {
  traefik_lb_ip = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].ip
}

# Cloudflare zone lookup (provider v5).
data "cloudflare_zone" "this" {
  filter = { name = local.cloudflare_zone_name }
}

# Cloudflare's published edge ranges. Used ONLY for the Traefik entrypoint's trusted
# forwarded-headers list, so the origin trusts XFF from Cloudflare and nobody else.
# (Service.loadBalancerSourceRanges is deliberately not used — the OCI CCM ignores it
# for NLBs; the network-level lockdown lives in lb_nsg/worker_nsg in ../ddyyconsulting.)
# IPv4 only: the origin NLB has no IPv6 address and the A record has no AAAA peer,
# so Cloudflare always reaches it over IPv4.
# NOTE: ../ddyyconsulting derives the same list from https://www.cloudflare.com/ips-v4
# instead. If the two ever disagree, an edge IP the NSG admits but trustedIPs omits
# makes Traefik discard XFF, and the ipAllowList then 403s legitimate clients.
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
