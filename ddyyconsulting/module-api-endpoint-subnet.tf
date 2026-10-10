# API endpoint subnet is PRIVATE: the API endpoint has no public IP and is
# reached via the OCI Bastion. This subnet is also the bastion target.
module "api_endpoint_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id            = module.dev_compartment.compartment_id
  prohibit_internet_ingress = true
  route_table_id            = module.k8s_vcn.private_route_table_id
  subnet_cidr_block         = local.cidr_api_subnet
  subnet_dns_label          = "apiep"
  subnet_freeform_tags      = local.default_tags
  vcn_id                    = module.k8s_vcn.vcn_id
}
