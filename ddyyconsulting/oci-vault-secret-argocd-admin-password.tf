resource "oci_vault_secret" "argocd_admin_password_bcrypt" {
  compartment_id = module.dev_compartment.compartment_id
  key_id         = module.vault.key_id
  secret_name    = "argocd-admin-password-bcrypt"
  vault_id       = module.vault.vault_id
  description    = "Bcrypt hash of the ArgoCD admin password, synced by External Secrets Operator."
  freeform_tags  = local.default_tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.argocd_admin_password_bcrypt)
  }
}

resource "oci_vault_secret" "argocd_admin_password_mtime" {
  compartment_id = module.dev_compartment.compartment_id
  key_id         = module.vault.key_id
  secret_name    = "argocd-admin-password-mtime"
  vault_id       = module.vault.vault_id
  description    = "Fixed RFC3339 timestamp for argocdServerAdminPasswordMtime, synced by External Secrets Operator."
  freeform_tags  = local.default_tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.argocd_admin_password_mtime)
  }
}
