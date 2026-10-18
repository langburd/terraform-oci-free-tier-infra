# Separate DEFAULT vault (free) for the private CA's signing key. OCI Certificates requires
# an HSM-protected asymmetric key; RSA with key_length 512 is RSA-4096. One HSM key version
# is within the free 20.
module "vault_certificates" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vault/v2.0.0"
  # source = "../../terraform-oci-free-tier-modules/oci/vault"

  compartment_id      = module.dev_compartment.compartment_id
  create_key          = true
  key_algorithm       = "RSA"
  key_display_name    = "mysql-ca"
  key_length          = 512
  key_protection_mode = "HSM"
  vault_display_name  = "ddyy-certificates"
  vault_freeform_tags = local.default_tags
  vault_type          = "DEFAULT"
}
