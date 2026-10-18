# MySQL is reachable only from the worker subnet. OKE runs flannel, so pod traffic to
# VCN addresses leaves with the node IP: cidr_worker covers every pod. The workers reach
# 3306 through their existing worker_to_internet egress rule (TCP to 0.0.0.0/0).
module "mysql_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v2.0.0"

  compartment_id = module.dev_compartment.compartment_id

  ingress_rules = {
    workers_to_mysql = {
      description = "Worker nodes (and their pods) to MySQL"
      protocol    = "6"
      source      = local.cidr_worker
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 3306, max = 3306 } }
    }
  }

  nsg_display_name  = "mysql-nsg"
  nsg_freeform_tags = local.default_tags
  vcn_id            = module.k8s_vcn.vcn_id
}
