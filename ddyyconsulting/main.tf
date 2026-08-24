locals {
  profile_name = "ddyyconsulting"
  default_tags = {
    "Environment" = "Dev"
    "GitRepo"     = "https://github.com/langburd/terraform-oci-free-tier-infra/tree/master/ddyyconsulting"
    "ManagedBy"   = "OpenTofu"
  }
}

module "oci_profile_reader" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oci_profile_reader/v1.0.2"
  # source       = "../../terraform-oci-free-tier-modules/oci/oci_profile_reader"
  profile_name = local.profile_name
}

module "dev_compartment" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/identity/v1.1.1"
  # source = "../../terraform-oci-free-tier-modules/oci/identity"

  oci_root_compartment      = module.oci_profile_reader.oci_profile_data.tenancy
  compartment_name          = "Dev"
  compartment_description   = "Compartment used for a Development purposes"
  compartment_freeform_tags = local.default_tags
}

module "dev_budget" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/budget/v1.1.1"
  # source = "../../terraform-oci-free-tier-modules/oci/budget"

  budget_compartment_id = module.oci_profile_reader.oci_profile_data.tenancy
  budget_freeform_tags  = local.default_tags
  budget_targets        = [module.oci_profile_reader.oci_profile_data.tenancy]

  alert_freeform_tags = local.default_tags
  alert_recipients    = "alerts@ddyy.pro"
}

# --- OKE cluster supporting data sources and locals ---

data "oci_core_services" "all" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# Cloudflare's published edge ranges. argocd.ddyy.pro is a proxied record, so all
# legitimate traffic to the public LB originates from these. IPv4 only — the LB has
# no IPv6 address, so Cloudflare always reaches it over IPv4.
# The ddyyconsulting-k8s layer reads the same list via data.cloudflare_ip_ranges.
data "http" "cloudflare_ips_v4" {
  url = "https://www.cloudflare.com/ips-v4"
}

locals {
  # Region-agnostic Oracle Services Network CIDR label, used by the Service Gateway routes.
  oci_services_candidates = [for s in data.oci_core_services.all.services :
    s.cidr_block if length(regexall("All .* Services In Oracle Services Network", s.name)) > 0
  ]
  oci_services_cidr = local.oci_services_candidates[0]

  # Caller's current public IP as a /32, used to scope bastion client access.
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  # SSH public key with fallback to default location.
  ssh_public_key = var.ssh_public_key != null ? var.ssh_public_key : file(pathexpand("~/.ssh/langburd.pub"))

  # CIDR blocks — single source of truth for all NSG rules and subnet definitions.
  cidr_vcn        = "10.0.0.0/16"
  cidr_api_subnet = "10.0.1.0/24"
  cidr_worker     = "10.0.2.0/24"
  cidr_lb         = "10.0.3.0/24"
  cidr_all        = "0.0.0.0/0"

  cloudflare_ipv4_cidrs = compact(split("\n", chomp(data.http.cloudflare_ips_v4.response_body)))

  # LB ingress allowlist: Cloudflare's edge ranges (the FQDN is a proxied record),
  # plus any explicit extras. NOT the caller's /32 — the operator's browser never
  # talks to the origin directly, and pinning it here would lock Cloudflare out.
  # Per-user access control lives in the ddyyconsulting-k8s layer instead
  # (Cloudflare WAF rule + Traefik ipAllowList, both scoped to the hostname).
  lb_allowed_cidrs = concat(local.cloudflare_ipv4_cidrs, var.lb_extra_ingress_cidrs)

  # Worker node shape.
  node_shape = "VM.Standard.A1.Flex"

  # Kubernetes version — upgrade one minor at a time (OCI constraint).
  kubernetes_version = "v1.34.2"
}

# Fail early with a clear message if the Oracle Services Network CIDR label can
# not be resolved (e.g. the service name format changed) before indexing it.
check "oci_services_cidr_resolved" {
  assert {
    condition     = length(local.oci_services_candidates) > 0
    error_message = "Could not resolve the 'All Services In Oracle Services Network' CIDR from oci_core_services."
  }
}

# OKE-compatible ARM image for the node pool, resolved via the OKE node pool options API.
# Filters to the newest OL8 aarch64 image matching the configured kubernetes version.
# OL9 OKE ARM images are not yet available in il-jerusalem-1 as of 2026-06.
# To list available images: oci ce node-pool-options get --node-pool-option-id all \
#   --profile ddyyconsulting --query 'data.sources[?contains("source-name",`aarch64`)]."source-name"'
data "oci_containerengine_node_pool_option" "arm" {
  node_pool_option_id = "all"
  compartment_id      = module.dev_compartment.compartment_id
}

locals {
  # OL8 aarch64 OKE images matching the configured kubernetes version.
  arm_image_candidates = [
    for s in data.oci_containerengine_node_pool_option.arm.sources :
    s.image_id
    if can(regex("Oracle-Linux-8.*aarch64.*OKE-${replace(local.kubernetes_version, "v", "")}", s.source_name))
  ]
  arm_image_id = local.arm_image_candidates[0]
}

# Fail early with a clear message if the configured kubernetes_version has no
# matching OL8 aarch64 OKE image (e.g. version bumped before the image exists).
check "arm_image_available" {
  assert {
    condition     = length(local.arm_image_candidates) > 0
    error_message = "No OL8 aarch64 OKE image found for kubernetes_version ${local.kubernetes_version} in this region."
  }
}

# --- OKE networking ---

module "k8s_vcn" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/vcn/v1.1.2"

  compartment_id          = module.dev_compartment.compartment_id
  vcn_display_name        = "k8s-vcn"
  vcn_dns_label           = "k8svcn"
  vcn_cidr_blocks         = [local.cidr_vcn]
  create_internet_gateway = true
  create_nat_gateway      = true
  create_service_gateway  = true
  vcn_freeform_tags       = local.default_tags
}

# API endpoint subnet is PRIVATE: the API endpoint has no public IP and is
# reached via the OCI Bastion. This subnet is also the bastion target.
module "api_endpoint_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id            = module.dev_compartment.compartment_id
  vcn_id                    = module.k8s_vcn.vcn_id
  subnet_cidr_block         = local.cidr_api_subnet
  route_table_id            = module.k8s_vcn.private_route_table_id
  subnet_dns_label          = "apiep"
  prohibit_internet_ingress = true
  subnet_freeform_tags      = local.default_tags
}

module "worker_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id            = module.dev_compartment.compartment_id
  vcn_id                    = module.k8s_vcn.vcn_id
  subnet_cidr_block         = local.cidr_worker
  route_table_id            = module.k8s_vcn.private_route_table_id
  subnet_dns_label          = "workers"
  prohibit_internet_ingress = true
  subnet_freeform_tags      = local.default_tags
}

module "lb_subnet" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/subnet/v1.1.1"

  compartment_id       = module.dev_compartment.compartment_id
  vcn_id               = module.k8s_vcn.vcn_id
  subnet_cidr_block    = local.cidr_lb
  route_table_id       = module.k8s_vcn.public_route_table_id
  subnet_dns_label     = "lbsub"
  subnet_freeform_tags = local.default_tags
}

# --- OKE network security groups ---

module "api_endpoint_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id    = module.dev_compartment.compartment_id
  vcn_id            = module.k8s_vcn.vcn_id
  nsg_display_name  = "oke-api-endpoint-nsg"
  nsg_freeform_tags = local.default_tags

  ingress_rules = {
    workers_to_api = {
      protocol    = "6"
      source      = local.cidr_worker
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 6443, max = 6443 } }
      description = "Worker nodes to Kubernetes API"
    }
    workers_to_api_12250 = {
      protocol    = "6"
      source      = local.cidr_worker
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 12250, max = 12250 } }
      description = "Worker nodes to OKE control plane"
    }
    bastion_to_api = {
      protocol    = "6"
      source      = local.cidr_api_subnet
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 6443, max = 6443 } }
      description = "Bastion session (in API subnet) to Kubernetes API"
    }
    path_mtu_icmp = {
      protocol     = "1"
      source       = local.cidr_worker
      source_type  = "CIDR_BLOCK"
      icmp_options = { type = 3, code = 4 }
      description  = "Path MTU discovery from workers"
    }
  }

  egress_rules = {
    api_to_workers = {
      protocol         = "6"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      description      = "API endpoint to worker nodes"
    }
    api_to_oci_services = {
      protocol         = "6"
      destination      = local.oci_services_cidr
      destination_type = "SERVICE_CIDR_BLOCK"
      tcp_options      = { destination_port_range = { min = 443, max = 443 } }
      description      = "OKE cluster to OCI services"
    }
  }
}

module "worker_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id    = module.dev_compartment.compartment_id
  vcn_id            = module.k8s_vcn.vcn_id
  nsg_display_name  = "oke-worker-nsg"
  nsg_freeform_tags = local.default_tags

  ingress_rules = merge(
    {
      worker_to_worker = {
        protocol    = "all"
        source      = local.cidr_worker
        source_type = "CIDR_BLOCK"
        description = "Inter-worker communication"
      }
      api_to_workers = {
        protocol    = "6"
        source      = local.cidr_api_subnet
        source_type = "CIDR_BLOCK"
        description = "API endpoint to worker nodes"
      }
      path_mtu_icmp = {
        protocol     = "1"
        source       = local.cidr_all
        source_type  = "CIDR_BLOCK"
        icmp_options = { type = 3, code = 4 }
        description  = "Path MTU discovery"
      }
      # externalTrafficPolicy: Local makes kube-proxy allocate a healthCheckNodePort
      # and the NLB probes THAT, not the shared kube-proxy port 10256. Its number is
      # assigned dynamically from the NodePort range and cannot be pinned without
      # recreating the Service, so the rule covers the whole range. Without this the
      # NLB marks every backend CRITICAL and answers nothing — Cloudflare 522.
      nlb_healthcheck_nodeports = {
        protocol    = "6"
        source      = local.cidr_lb
        source_type = "CIDR_BLOCK"
        tcp_options = { destination_port_range = { min = 30000, max = 32767 } }
        description = "NLB health checks to NodePort range"
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
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 30000, max = 32767 } }
      description = "Cloudflare ${cidr} to NodePort services"
    } },
  )

  egress_rules = {
    worker_to_worker = {
      protocol         = "all"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      description      = "Inter-worker communication"
    }
    worker_to_internet = {
      protocol         = "6"
      destination      = local.cidr_all
      destination_type = "CIDR_BLOCK"
      description      = "Internet access via NAT"
    }
    worker_to_api_6443 = {
      protocol         = "6"
      destination      = local.cidr_api_subnet
      destination_type = "CIDR_BLOCK"
      tcp_options      = { destination_port_range = { min = 6443, max = 6443 } }
      description      = "Worker to Kubernetes API"
    }
    worker_to_api_12250 = {
      protocol         = "6"
      destination      = local.cidr_api_subnet
      destination_type = "CIDR_BLOCK"
      tcp_options      = { destination_port_range = { min = 12250, max = 12250 } }
      description      = "Worker to OKE control plane"
    }
    worker_to_oci_services = {
      protocol         = "6"
      destination      = local.oci_services_cidr
      destination_type = "SERVICE_CIDR_BLOCK"
      description      = "Worker to OCI services"
    }
  }
}

module "lb_nsg" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/network_security_group/v1.0.1"

  compartment_id    = module.dev_compartment.compartment_id
  vcn_id            = module.k8s_vcn.vcn_id
  nsg_display_name  = "oke-lb-nsg"
  nsg_freeform_tags = local.default_tags

  ingress_rules = merge(
    { for cidr in local.lb_allowed_cidrs : "http_ingress_${replace(cidr, "/", "_")}" => {
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 80, max = 80 } }
      description = "HTTP ingress from ${cidr}"
    } },
    { for cidr in local.lb_allowed_cidrs : "https_ingress_${replace(cidr, "/", "_")}" => {
      protocol    = "6"
      source      = cidr
      source_type = "CIDR_BLOCK"
      tcp_options = { destination_port_range = { min = 443, max = 443 } }
      description = "HTTPS ingress from ${cidr}"
    } },
  )

  egress_rules = {
    lb_to_nodeport = {
      protocol         = "6"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      tcp_options      = { destination_port_range = { min = 30000, max = 32767 } }
      description      = "LB to NodePort services"
    }
    lb_to_healthcheck = {
      protocol         = "6"
      destination      = local.cidr_worker
      destination_type = "CIDR_BLOCK"
      tcp_options      = { destination_port_range = { min = 10256, max = 10256 } }
      description      = "kube-proxy health check"
    }
  }
}

# --- OCI Bastion service for private API endpoint access ---
# Creates the managed bastion only. SSH/port-forward sessions are opened
# out-of-band (see the oke_bastion_session_hint output).
module "bastion" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/bastion/v1.1.1"

  compartment_id               = module.dev_compartment.compartment_id
  bastion_name                 = "ddyyokebastion"
  target_subnet_id             = module.api_endpoint_subnet.subnet_id
  client_cidr_block_allow_list = [local.my_cidr]
  bastion_freeform_tags        = local.default_tags
}

# --- OKE cluster (private API endpoint) and ARM node pool ---

module "oke_cluster" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oke_cluster/v1.0.1"

  compartment_id                = module.dev_compartment.compartment_id
  vcn_id                        = module.k8s_vcn.vcn_id
  cluster_name                  = var.cluster_name
  kubernetes_version            = local.kubernetes_version
  endpoint_subnet_id            = module.api_endpoint_subnet.subnet_id
  endpoint_is_public_ip_enabled = false
  endpoint_nsg_ids              = [module.api_endpoint_nsg.nsg_id]
  service_lb_subnet_ids         = [module.lb_subnet.subnet_id]
  cluster_freeform_tags         = local.default_tags
}

module "oke_node_pool" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oke_node_pool/v1.0.1"

  compartment_id           = module.dev_compartment.compartment_id
  cluster_id               = module.oke_cluster.cluster_id
  node_pool_name           = "${var.cluster_name}-arm-pool"
  kubernetes_version       = local.kubernetes_version
  image_id                 = local.arm_image_id
  subnet_id                = module.worker_subnet.subnet_id
  node_shape               = local.node_shape
  node_shape_ocpus         = var.node_ocpus
  node_shape_memory_in_gbs = var.node_memory_in_gbs
  node_count               = var.node_count
  boot_volume_size_in_gbs  = var.boot_volume_size_in_gbs
  nsg_ids                  = [module.worker_nsg.nsg_id]
  ssh_public_key           = local.ssh_public_key
  node_pool_freeform_tags  = local.default_tags
}
