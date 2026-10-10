# --- OCI Bastion service for private API endpoint access ---
# Creates the managed bastion only. SSH/port-forward sessions are opened
# out-of-band (see the oke_bastion_session_hint output).
module "bastion" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/bastion/v1.1.1"

  bastion_freeform_tags        = local.default_tags
  bastion_name                 = "ddyyokebastion"
  client_cidr_block_allow_list = [local.my_cidr]
  compartment_id               = module.dev_compartment.compartment_id
  target_subnet_id             = module.api_endpoint_subnet.subnet_id
}
