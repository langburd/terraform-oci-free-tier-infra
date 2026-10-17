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

variable "offsite_backup_age_recipient" {
  description = "age public key (age1...) the Vaultwarden off-site backup is encrypted to. The private key stays offline, never in the cluster or OCI (langburd/gitops docs/vaultwarden.md)."
  type        = string

  validation {
    condition     = can(regex("^age1[02-9ac-hj-np-z]{58}$", var.offsite_backup_age_recipient))
    error_message = "offsite_backup_age_recipient must be an age X25519 public key (age1 followed by 58 bech32 characters)."
  }
}

variable "vaultwarden_r2_access_key_id" {
  description = "Access key ID of the R2 API token scoped to the ddyy-vaultwarden-offsite bucket (Object Read & Write). Null until the token is created after the bucket."
  type        = string
  default     = null
  sensitive   = true
}

variable "vaultwarden_r2_secret_access_key" {
  description = "Secret access key of the R2 API token scoped to the ddyy-vaultwarden-offsite bucket. Null until the token is created after the bucket."
  type        = string
  default     = null
  sensitive   = true
}
