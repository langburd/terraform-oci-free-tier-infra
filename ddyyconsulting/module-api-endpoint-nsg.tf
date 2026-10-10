# --- OKE network security groups ---

module "api_endpoint_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id = module.dev_compartment.compartment_id

  egress_rules = {
    api_to_oci_services = {
      description      = "OKE cluster to OCI services"
      destination      = local.oci_services_cidr
      destination_type = "SERVICE_CIDR_BLOCK"
      protocol         = "6"
      tcp_options      = { destination_port_range = { min = 443, max = 443 } }
    }
    api_to_workers = {
      description      = "API endpoint to worker nodes"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
    }
  }

  ingress_rules = {
    bastion_to_api = {
      description = "Bastion session (in API subnet) to Kubernetes API"
      protocol    = "6"
      source      = local.cidr_api_subnet
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 6443, max = 6443 } }
    }
    path_mtu_icmp = {
      description  = "Path MTU discovery from workers"
      icmp_options = { type = 3, code = 4 }
      protocol     = "1"
      source       = local.cidr_worker
      source_type  = "CIDR_BLOCK"
    }
    workers_to_api = {
      description = "Worker nodes to Kubernetes API"
      protocol    = "6"
      source      = local.cidr_worker
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 6443, max = 6443 } }
    }
    workers_to_api_12250 = {
      description = "Worker nodes to OKE control plane"
      protocol    = "6"
      source      = local.cidr_worker
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 12250, max = 12250 } }
    }
  }

  nsg_display_name  = "oke-api-endpoint-nsg"
  nsg_freeform_tags = local.default_tags
  vcn_id            = module.k8s_vcn.vcn_id
}
