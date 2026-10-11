variable "cloudflare_api_token" {
  description = "Cloudflare API token for the TF provider (Zone:DNS:Edit on the zone)."
  type        = string
  sensitive   = true
}

# NOTE: deliberately NOT named argocd_allowed_cidrs — ../ddyyconsulting used that name
# for something else (LB NSG ingress sources; now lb_extra_ingress_cidrs). A shared
# TF_VAR_argocd_allowed_cidrs export would have collapsed that NSG to this list and
# locked Cloudflare out of the origin.
variable "argocd_client_cidrs" {
  description = "CIDRs permitted to reach argocd.ddyy.pro. Enforced per-FQDN at two layers: a Cloudflare WAF rule scoped to the hostname, and a Traefik ipAllowList Middleware on the ArgoCD HTTPRoute. Other hostnames are unaffected."
  type        = list(string)
  sensitive   = true

  validation {
    condition     = length(var.argocd_client_cidrs) > 0 && alltrue([for c in var.argocd_client_cidrs : can(cidrhost(c, 0))])
    error_message = "argocd_client_cidrs must be a non-empty list of valid CIDRs (e.g. [\"203.0.113.4/32\"])."
  }
}
