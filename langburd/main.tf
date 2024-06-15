module "oci_profile_reader" {
  source       = "git@github.com:langburd/terraform-oci-free-tier-modules.git//modules/oci_profile_reader?ref=master"
  profile_name = "LANGBURD"
}

module "compartment" {
  # source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//modules/identity?ref=master"
  source               = "../../terraform-oci-free-tier-modules/modules/identity"
  oci_root_compartment = module.oci_profile_reader.oci_profile_data.tenancy
}
