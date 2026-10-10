module "worker_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id = module.dev_compartment.compartment_id

  egress_rules = {
    worker_to_api_12250 = {
      description      = "Worker to OKE control plane"
      destination      = local.cidr_api_subnet
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
      tcp_options      = { destination_port_range = { min = 12250, max = 12250 } }
    }
    worker_to_api_6443 = {
      description      = "Worker to Kubernetes API"
      destination      = local.cidr_api_subnet
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
      tcp_options      = { destination_port_range = { min = 6443, max = 6443 } }
    }
    worker_to_internet = {
      description      = "Internet access via NAT"
      destination      = local.cidr_all
      destination_type = "CIDR_BLOCK"
      protocol         = "6"
    }
    worker_to_oci_services = {
      description      = "Worker to OCI services"
      destination      = local.oci_services_cidr
      destination_type = "SERVICE_CIDR_BLOCK"
      protocol         = "6"
    }
    worker_to_worker = {
      description      = "Inter-worker communication"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      protocol         = "all"
    }
  }

  ingress_rules = merge(
    {
      api_to_workers = {
        description = "API endpoint to worker nodes"
        protocol    = "6"
        source      = local.cidr_api_subnet
        source_type = "CIDR_BLOCK"
      }
      # externalTrafficPolicy: Local makes kube-proxy allocate a healthCheckNodePort
      # and the NLB probes THAT, not the shared kube-proxy port 10256. Its number is
      # assigned dynamically from the NodePort range and cannot be pinned without
      # recreating the Service, so the rule covers the whole range. Without this the
      # NLB marks every backend CRITICAL and answers nothing — Cloudflare 522.
      nlb_healthcheck_nodeports = {
        description = "NLB health checks to NodePort range"
        protocol    = "6"
        source      = local.cidr_lb
        source_type = "CIDR_BLOCK"
        tcp_options = { destination_port_range = { min = 30000, max = 32767 } }
      }
      path_mtu_icmp = {
        description  = "Path MTU discovery"
        icmp_options = { type = 3, code = 4 }
        protocol     = "1"
        source       = local.cidr_all
        source_type  = "CIDR_BLOCK"
      }
      worker_to_worker = {
        description = "Inter-worker communication"
        protocol    = "all"
        source      = local.cidr_worker
        source_type = "CIDR_BLOCK"
      }
    },
    # Data path. The NLB has is-preserve-source = true (a consequence of
    # externalTrafficPolicy: Local), so packets arrive at the NodePort carrying the
    # ORIGINAL client address — a Cloudflare edge IP — not the LB's private IP in
    # cidr_lb. Rules scoped to cidr_lb therefore never match the data path.
    #
    # These rules are also the origin's real lockdown: Service.loadBalancerSourceRanges
    # is silently ignored by the OCI CCM for NLBs (it creates no NSG and writes no
    # security list rule), so this NSG is the only thing keeping non-Cloudflare
    # traffic out of the cluster.
    { for cidr in local.cloudflare_ipv4_cidrs : "cloudflare_nodeports_${replace(cidr, "/", "_")}" => {
      description = "Cloudflare ${cidr} to NodePort services"
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 30000, max = 32767 } }
    } },
  )

  nsg_display_name  = "oke-worker-nsg"
  nsg_freeform_tags = local.default_tags
  vcn_id            = module.k8s_vcn.vcn_id
}
