# Edge half of the per-FQDN IP allowlist (the origin half is the Traefik Middleware
# in bootstrap.tf). Blocks non-allowlisted clients at Cloudflare, before the request
# ever reaches the OCI load balancer.
#
# The expression is scoped to the ArgoCD hostname, so every other name in the zone —
# proxied or not — is untouched.
#
# Requires the TF Cloudflare token to carry Zone -> Zone WAF -> Edit in addition to
# Zone -> DNS -> Edit; see docs/cloudflare-tokens.md.
#
# CAUTION: cloudflare_ruleset owns the ENTIRE http_request_firewall_custom ruleset
# for the zone. Custom rules added by hand in the dashboard will be deleted on the
# next apply — add them here instead.
resource "cloudflare_ruleset" "zone_firewall_custom" {
  zone_id = data.cloudflare_zone.this.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [{
    ref         = "argocd_ip_allowlist"
    description = "Allow ${local.argocd_fqdn} only from argocd_client_cidrs"
    expression  = "(http.host eq \"${local.argocd_fqdn}\" and not ip.src in {${join(" ", var.argocd_client_cidrs)}})"
    action      = "block"
    enabled     = true
  }]
}
