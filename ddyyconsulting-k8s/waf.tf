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
# for the zone. Custom rules added by hand in the dashboard belong here instead.
#
# Cloudflare permits exactly ONE phase entry-point ruleset per zone, and this resource
# creates it. If the zone already has any custom WAF rule (i.e. the entry point exists),
# the first apply FAILS instead of adopting it — import it once before applying:
#   RULESET_ID=$(curl -sS -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" \
#     "https://api.cloudflare.com/client/v4/zones/<zone-id>/rulesets/phases/http_request_firewall_custom/entrypoint" \
#     | jq -r .result.id)
#   tofu import cloudflare_ruleset.zone_firewall_custom "<zone-id>/$RULESET_ID"
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
