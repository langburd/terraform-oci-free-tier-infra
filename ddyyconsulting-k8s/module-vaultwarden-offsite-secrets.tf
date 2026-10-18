# R2 credentials for the off-site backup CronJob, synced by External Secrets. The R2 API
# token is created by hand, scoped to the bucket above, after the bucket exists (see
# docs/cloudflare-tokens.md), so these secrets are only created once both values are set.
module "vaultwarden_offsite_secrets" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vault_secrets/v1.0.0"
  count  = nonsensitive(var.vaultwarden_r2_access_key_id != null && var.vaultwarden_r2_secret_access_key != null) ? 1 : 0

  compartment_id = data.terraform_remote_state.infra.outputs.dev_compartment_id
  key_id         = data.terraform_remote_state.infra.outputs.vault_key_id
  vault_id       = data.terraform_remote_state.infra.outputs.vault_id

  secrets = {
    vaultwarden-r2-access-key-id = {
      content     = var.vaultwarden_r2_access_key_id
      description = "R2 access key ID for the Vaultwarden off-site backup bucket."
    }
    vaultwarden-r2-secret-access-key = {
      content     = var.vaultwarden_r2_secret_access_key
      description = "R2 secret access key for the Vaultwarden off-site backup bucket."
    }
  }
}
