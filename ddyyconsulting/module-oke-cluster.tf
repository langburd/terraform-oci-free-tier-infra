# --- OKE cluster (private API endpoint) and ARM node pool ---

module "oke_cluster" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oke_cluster/v1.0.1"

  cluster_freeform_tags         = local.default_tags
  cluster_name                  = var.cluster_name
  compartment_id                = module.dev_compartment.compartment_id
  endpoint_is_public_ip_enabled = false
  endpoint_nsg_ids              = [module.api_endpoint_nsg.nsg_id]
  endpoint_subnet_id            = module.api_endpoint_subnet.subnet_id
  kubernetes_version            = local.kubernetes_version
  service_lb_subnet_ids         = [module.lb_subnet.subnet_id]
  vcn_id                        = module.k8s_vcn.vcn_id
}
