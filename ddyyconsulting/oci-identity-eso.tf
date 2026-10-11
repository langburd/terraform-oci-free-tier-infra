# Instance principal for External Secrets Operator: every worker instance in the Dev compartment.
resource "oci_identity_dynamic_group" "eso" {
  compartment_id = module.oci_profile_reader.oci_profile_data.tenancy
  name           = "ddyy-oke-workers"
  description    = "OKE worker instances in the Dev compartment (External Secrets Operator instance principal)."
  matching_rule  = "ALL {instance.compartment.id = '${module.dev_compartment.compartment_id}'}"
  freeform_tags  = local.default_tags
}

resource "oci_identity_policy" "eso" {
  compartment_id = module.dev_compartment.compartment_id
  name           = "ddyy-oke-eso-read-secrets"
  description    = "Allow External Secrets Operator to read secrets from the ddyy-gitops vault."
  freeform_tags  = local.default_tags

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.eso.name} to read secret-family in compartment id ${module.dev_compartment.compartment_id} where target.vault.id = '${module.vault.vault_id}'",
  ]
}
