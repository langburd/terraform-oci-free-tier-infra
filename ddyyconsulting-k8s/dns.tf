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
  filter = { name = var.cloudflare_zone_name }
}

resource "cloudflare_dns_record" "argocd" {
  zone_id = data.cloudflare_zone.this.zone_id
  name    = var.argocd_fqdn
  type    = "A"
  content = local.traefik_lb_ip
  ttl     = 60
  proxied = false # DNS-only: cert already issued via DNS-01; keep TLS pass-through to Traefik.
}
