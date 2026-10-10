module "k8s_vcn" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vcn/v1.1.2"

  compartment_id          = module.dev_compartment.compartment_id
  create_internet_gateway = true
  create_nat_gateway      = true
  create_service_gateway  = true
  vcn_cidr_blocks         = [local.cidr_vcn]
  vcn_display_name        = "k8s-vcn"
  vcn_dns_label           = "k8svcn"
  vcn_freeform_tags       = local.default_tags
}
