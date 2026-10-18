# Private subnet for managed databases (MySQL HeatWave). DNS label "db" gives DB
# endpoints names like <hostname_label>.db.k8svcn.oraclevcn.com.
module "db_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v2.0.0"

  compartment_id            = module.dev_compartment.compartment_id
  prohibit_internet_ingress = true
  route_table_id            = module.k8s_vcn.private_route_table_id
  subnet_cidr_block         = local.cidr_db
  subnet_dns_label          = local.dns_label_db_subnet
  subnet_freeform_tags      = local.default_tags
  vcn_id                    = module.k8s_vcn.vcn_id
}
