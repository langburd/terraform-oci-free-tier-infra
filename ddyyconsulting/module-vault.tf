module "vault" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vault/v1.1.0"
  # source = "../../terraform-oci-free-tier-modules/oci/vault"

  compartment_id      = module.dev_compartment.compartment_id
  create_key          = true
  key_display_name    = "ddyy-gitops"
  key_protection_mode = "SOFTWARE"
  vault_display_name  = "ddyy-gitops"
  vault_freeform_tags = local.default_tags
  vault_type          = "DEFAULT"
}
