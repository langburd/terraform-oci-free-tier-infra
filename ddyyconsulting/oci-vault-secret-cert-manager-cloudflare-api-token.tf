resource "oci_vault_secret" "cert_manager_cloudflare_api_token" {
  compartment_id = module.dev_compartment.compartment_id
  key_id         = module.vault.key_id
  secret_name    = "cert-manager-cloudflare-api-token"
  vault_id       = module.vault.vault_id
  description    = "Cloudflare API token for cert-manager DNS-01, synced by External Secrets Operator."
  freeform_tags  = local.default_tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.certmanager_cf_token)
  }
}
