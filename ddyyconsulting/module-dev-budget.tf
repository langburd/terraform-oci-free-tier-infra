module "dev_budget" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/budget/v1.1.1"
  # source = "../../terraform-oci-free-tier-modules/oci/budget"

  alert_freeform_tags   = local.default_tags
  alert_recipients      = "alerts@ddyy.pro"
  budget_compartment_id = module.oci_profile_reader.oci_profile_data.tenancy
  budget_freeform_tags  = local.default_tags
  budget_targets        = [module.oci_profile_reader.oci_profile_data.tenancy]
}
