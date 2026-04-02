locals {
  profile_name = "ddyyconsulting"
  default_tags = {
    "Environment" = "Dev"
    "GitRepo"     = "https://github.com/langburd/terraform-oci-free-tier-infra/tree/master/ddyyconsulting"
    "ManagedBy"   = "Terraform"
    "Owner"       = "avi@langburd.com"
  }
}

module "oci_profile_reader" {
  source       = "git@github.com:langburd/terraform-oci-free-tier-modules.git//oci/oci_profile_reader?ref=v1.0.0"
  profile_name = local.profile_name
}

module "dev_compartment" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//oci/identity?ref=v1.0.0"
  # source = "../../terraform-oci-free-tier-modules/oci/identity"

  oci_root_compartment      = module.oci_profile_reader.oci_profile_data.tenancy
  compartment_name          = "Dev"
  compartment_description   = "Compartment used for a Development purposes"
  compartment_freeform_tags = local.default_tags
}

module "dev_budget" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//oci/budget?ref=v1.0.0"
  # source = "../../terraform-oci-free-tier-modules/oci/budget"

  budget_compartment_id = module.dev_compartment.compartment_id
  budget_freeform_tags  = local.default_tags
  budget_targets        = [module.oci_profile_reader.oci_profile_data.tenancy]

  alert_freeform_tags = local.default_tags
  alert_recipients    = "alerts@ddyy.pro"
}
