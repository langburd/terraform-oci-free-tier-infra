locals {
  profile_name = "langburd"
}

module "oci_profile_reader" {
  # source       = "git@github.com:langburd/terraform-oci-free-tier-modules.git//modules/oci_profile_reader?ref=v1.0.1"
  source       = "../../terraform-oci-free-tier-modules/modules/oci_profile_reader"
  profile_name = local.profile_name
}

module "test_compartment" {
  # source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//modules/identity?ref=master"
  source = "../../terraform-oci-free-tier-modules/modules/identity"

  oci_root_compartment    = module.oci_profile_reader.oci_profile_data.tenancy
  compartment_name        = "test-compartment"
  compartment_description = "This is a Test Compartment"

  compartment_freeform_tags = {
    "Terraform"   = "true"
    "Environment" = "Dev"
  }
}

# module "dev_compartment" {
#   # source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//modules/identity?ref=master"
#   source = "../../terraform-oci-free-tier-modules/modules/identity"

#   oci_root_compartment      = module.oci_profile_reader.oci_profile_data.tenancy
#   compartment_name          = "Dev"
#   compartment_description   = "This is a Dev Compartment"
#   compartment_enable_delete = true
#   compartment_freeform_tags = {
#     "Terraform"   = "true"
#     "Environment" = "Dev"
#   }
# }
