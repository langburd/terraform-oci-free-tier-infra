# Vaultwarden secrets, synced into the vaultwarden namespace by External Secrets
# (langburd/gitops addons/vaultwarden/manifests/templates/external-secrets.yaml).
# The R2 off-site credentials live in ../ddyyconsulting-k8s next to the R2 bucket.
module "vaultwarden_secrets" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vault_secrets/v1.0.0"

  compartment_id = module.dev_compartment.compartment_id
  freeform_tags  = local.default_tags
  key_id         = module.vault.key_id
  vault_id       = module.vault.vault_id

  secrets = {
    vaultwarden-admin-token = {
      content     = var.vaultwarden_admin_token_argon2
      description = "Argon2 PHC hash of the Vaultwarden admin panel token (ADMIN_TOKEN)."
    }
    vaultwarden-mysql-admin-password = {
      content     = random_password.vaultwarden_mysql_admin.result
      description = "MySQL HeatWave admin password, used only by the vaultwarden-db-init Job."
    }
    vaultwarden-mysql-app-password = {
      content     = random_password.vaultwarden_mysql_app.result
      description = "Password of the vaultwarden MySQL user (DATABASE_URL, off-site mysqldump)."
    }
    vaultwarden-rsa-key = {
      content     = tls_private_key.vaultwarden_rsa.private_key_pem
      description = "Vaultwarden JWT signing key (PEM), shared by all replicas."
    }
    vaultwarden-s3-access-key-id = {
      content     = module.vaultwarden_s3_user.access_key_id
      description = "OCI Customer Secret Key ID for the Vaultwarden data bucket."
    }
    vaultwarden-s3-secret-access-key = {
      content     = module.vaultwarden_s3_user.secret_access_key
      description = "OCI Customer Secret Key secret for the Vaultwarden data bucket."
    }
  }
}
