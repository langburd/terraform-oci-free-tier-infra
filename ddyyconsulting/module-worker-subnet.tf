module "worker_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id            = module.dev_compartment.compartment_id
  prohibit_internet_ingress = true
  route_table_id            = module.k8s_vcn.private_route_table_id
  subnet_cidr_block         = local.cidr_worker
  subnet_dns_label          = "workers"
  subnet_freeform_tags      = local.default_tags
  vcn_id                    = module.k8s_vcn.vcn_id
}
