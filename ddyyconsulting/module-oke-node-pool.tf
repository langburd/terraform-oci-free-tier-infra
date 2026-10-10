module "oke_node_pool" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/oke_node_pool/v1.0.1"

  boot_volume_size_in_gbs  = var.boot_volume_size_in_gbs
  cluster_id               = module.oke_cluster.cluster_id
  compartment_id           = module.dev_compartment.compartment_id
  image_id                 = local.arm_image_id
  kubernetes_version       = local.kubernetes_version
  node_count               = var.node_count
  node_pool_freeform_tags  = local.default_tags
  node_pool_name           = "${var.cluster_name}-arm-pool"
  node_shape               = local.node_shape
  node_shape_memory_in_gbs = var.node_memory_in_gbs
  node_shape_ocpus         = var.node_ocpus
  nsg_ids                  = [module.worker_nsg.nsg_id]
  ssh_public_key           = local.ssh_public_key
  subnet_id                = module.worker_subnet.subnet_id
}
