module "lb_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id = module.dev_compartment.compartment_id

  egress_rules = {
    lb_to_healthcheck = {
      description      = "kube-proxy health check"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
      tcp_options      = { destination_port_range = { min = 10256, max = 10256 } }
    }
    lb_to_nodeport = {
      description      = "LB to NodePort services"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
      tcp_options      = { destination_port_range = { min = 30000, max = 32767 } }
    }
  }

  ingress_rules = merge(
    { for cidr in local.lb_allowed_cidrs : "http_ingress_${replace(cidr, "/", "_")}" => {
      description = "HTTP ingress from ${cidr}"
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 80, max = 80 } }
    } },
    { for cidr in local.lb_allowed_cidrs : "https_ingress_${replace(cidr, "/", "_")}" => {
      description = "HTTPS ingress from ${cidr}"
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 443, max = 443 } }
    } },
  )

  nsg_display_name  = "oke-lb-nsg"
  nsg_freeform_tags = local.default_tags
  vcn_id            = module.k8s_vcn.vcn_id
}
