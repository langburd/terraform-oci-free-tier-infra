# Reserved public IP for the ingress NLB. The OCI CCM attaches it to the NLB via the
# oci-network-load-balancer.oraclecloud.com/... service annotation, so private_ip_id drifts.
resource "oci_core_public_ip" "ingress" {
  compartment_id = module.dev_compartment.compartment_id
  lifetime       = "RESERVED"
  display_name   = "ddyy-oke-ingress"
  freeform_tags  = local.default_tags

  lifecycle {
    ignore_changes = [private_ip_id]
  }
}
