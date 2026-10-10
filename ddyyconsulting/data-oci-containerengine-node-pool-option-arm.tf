# OKE-compatible ARM image for the node pool, resolved via the OKE node pool options API.
# Filters to the newest OL8 aarch64 image matching the configured kubernetes version.
# OL9 OKE ARM images are not yet available in il-jerusalem-1 as of 2026-06.
# To list available images: oci ce node-pool-options get --node-pool-option-id all \
#   --profile ddyyconsulting --query 'data.sources[?contains("source-name",`aarch64`)]."source-name"'
data "oci_containerengine_node_pool_option" "arm" {
  compartment_id      = module.dev_compartment.compartment_id
  node_pool_option_id = "all"
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
