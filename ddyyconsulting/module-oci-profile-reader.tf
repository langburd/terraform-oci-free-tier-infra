module "oci_profile_reader" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oci_profile_reader/v1.0.2"
  # source       = "../../terraform-oci-free-tier-modules/oci/oci_profile_reader"

  profile_name = local.profile_name
}
