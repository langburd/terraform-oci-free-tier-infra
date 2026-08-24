variable "cloudflare_api_token" {
  description = "Cloudflare API token for the TF provider (Zone:DNS:Edit on the zone)."
  type        = string
  sensitive   = true
}

variable "certmanager_cf_token" {
  description = "Cloudflare API token for cert-manager DNS-01 (Zone:DNS:Edit + Zone:Zone:Read on the zone)."
  type        = string
  sensitive   = true
}

variable "argocd_admin_password_bcrypt" {
  description = "Bcrypt hash of the ArgoCD admin password."
  type        = string
  sensitive   = true
}

variable "argocd_admin_password_mtime" {
  description = "Fixed RFC3339 timestamp for argocdServerAdminPasswordMtime. Set ONCE (e.g. 2026-06-27T00:00:00Z). Changing it resets the admin password; do not use a dynamic value."
  type        = string
  default     = "2026-06-27T00:00:00Z"

  validation {
    condition     = can(formatdate("YYYY-MM-DD", var.argocd_admin_password_mtime))
    error_message = "argocd_admin_password_mtime must be an RFC3339 timestamp (e.g. 2026-06-27T00:00:00Z)."
  }
}
