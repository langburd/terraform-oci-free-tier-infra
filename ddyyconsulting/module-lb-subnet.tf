module "lb_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id       = module.dev_compartment.compartment_id
  route_table_id       = module.k8s_vcn.public_route_table_id
  subnet_cidr_block    = local.cidr_lb
  subnet_dns_label     = "lbsub"
  subnet_freeform_tags = local.default_tags
  vcn_id               = module.k8s_vcn.vcn_id
}
