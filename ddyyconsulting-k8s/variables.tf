variable "argocd_fqdn" {
  description = "FQDN for the ArgoCD UI."
  type        = string
  default     = "argocd.ddyy.pro"
}

variable "cloudflare_zone_name" {
  description = "Cloudflare DNS zone hosting the FQDN."
  type        = string
  default     = "ddyy.pro"
}

variable "acme_email" {
  description = "Contact email for Let's Encrypt ACME registration."
  type        = string
  default     = "alerts@ddyy.pro"
}

variable "gitops_repo_url" {
  description = "SSH (scp-style) URL of the private GitOps repo. MUST be git@host:org/repo.git, not https:// — ArgoCD matches the SSH key only against scp-style URLs."
  type        = string
  default     = "git@github.com:langburd/gitops.git"

  validation {
    condition     = can(regex("^[^@]+@[^:]+:.+\\.git$", var.gitops_repo_url))
    error_message = "gitops_repo_url must be scp-style SSH, e.g. git@github.com:langburd/gitops.git."
  }
}

variable "gitops_repo_path" {
  description = "Path inside the GitOps repo for the app-of-apps root."
  type        = string
  default     = "apps"
}

variable "gitops_repo_branch" {
  description = "Branch the ArgoCD root app tracks."
  type        = string
  default     = "master"
}

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
  description = "Bcrypt hash of the ArgoCD admin password (htpasswd -nbBC 10 \"\" <pw> | tr -d ':\\n' | sed 's/$2y/$2a/')."
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
