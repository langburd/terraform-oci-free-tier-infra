module "dev_compartment" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/identity/v1.1.1"
  # source = "../../terraform-oci-free-tier-modules/oci/identity"

  compartment_description   = "Compartment used for a Development purposes"
  compartment_freeform_tags = local.default_tags
  compartment_name          = "Dev"
  oci_root_compartment      = module.oci_profile_reader.oci_profile_data.tenancy
}
