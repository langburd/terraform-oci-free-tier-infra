# Cloudflare's published edge ranges. argocd.ddyy.pro is a proxied record, so all
# legitimate traffic to the public LB originates from these. IPv4 only — the LB has
# no IPv6 address, so Cloudflare always reaches it over IPv4.
# The ddyyconsulting-k8s layer reads the same list via data.cloudflare_ip_ranges.
# The http data source does NOT fail on a non-2xx response, so the status is asserted
# here: an error page would otherwise parse into garbage CIDRs, and an empty body into
# an EMPTY list — which silently strips every Cloudflare rule from lb_nsg and
# worker_nsg and cuts the origin off from the edge.
data "http" "cloudflare_ips_v4" {
  url = "https://www.cloudflare.com/ips-v4"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "https://www.cloudflare.com/ips-v4 returned HTTP ${self.status_code}, expected 200."
    }
    # A hard error, not a `check` warning: an empty/garbage list applies cleanly and
    # leaves the origin with no edge access at all.
    postcondition {
      condition = length(compact(split("\n", chomp(self.response_body)))) > 0 && alltrue([
        for c in compact(split("\n", chomp(self.response_body))) : can(cidrhost(c, 0))
      ])
      error_message = "https://www.cloudflare.com/ips-v4 did not return a non-empty list of valid IPv4 CIDRs."
    }
  }
}

locals {
  cloudflare_ipv4_cidrs = compact(split("\n", chomp(data.http.cloudflare_ips_v4.response_body)))

  # LB ingress allowlist: Cloudflare's edge ranges (the FQDN is a proxied record),
  # plus any explicit extras. NOT the caller's /32 — the operator's browser never
  # talks to the origin directly, and pinning it here would lock Cloudflare out.
  # Per-user access control lives in the ddyyconsulting-k8s layer instead
  # (Cloudflare WAF rule + Traefik ipAllowList, both scoped to the hostname).
  lb_allowed_cidrs = concat(local.cloudflare_ipv4_cidrs, var.lb_extra_ingress_cidrs)
}
