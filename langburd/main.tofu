locals {
  profile_name = "langburd"
  name         = "kubernetes-on-arm-with-oracle" # "cloudblock-compartment" # "pihole-vpn"
  # name = "pihole-vpn"
}

module "oci_profile_reader" {
  # source       = "git@github.com:langburd/terraform-oci-free-tier-modules.git//oci/oci_profile_reader?ref=v1.0.1"
  source       = "../../terraform-oci-free-tier-modules/oci/oci_profile_reader"
  profile_name = local.profile_name
}

module "compartment" {
  # source = "git@github.com:langburd/terraform-oci-free-tier-modules.git//oci/identity?ref=master"
  source = "../../terraform-oci-free-tier-modules/oci/identity"

  oci_root_compartment      = module.oci_profile_reader.oci_profile_data.tenancy
  compartment_description   = "Compartment for Pi-Hole and WireGuard VPN"
  compartment_enable_delete = true
  compartment_name          = local.name
  compartment_freeform_tags = {
    "Terraform"   = "true"
    "Environment" = "Production"
  }
}

# module "network" {
#   source = "../../terraform-oci-free-tier-modules/oci/network"

#   # tenancy_ocid     = module.oci_profile_reader.oci_profile_data.tenancy
#   compartment_ocid = module.compartment.compartment_id
# }

# output "compartment_id" {
#   description = "The OCID of the compartment"
#   value       = module.compartment.compartment_id
# }

# output "compartment_name" {
#   description = "The name of the compartment"
#   value       = module.compartment.compartment_name
# }

# output "compartment_description" {
#   description = "The description of the compartment"
#   value       = module.compartment.compartment_description
# }

# output "compartment_freeform_tags" {
#   description = "The freeform tags of the compartment"
#   value       = module.compartment.compartment_freeform_tags
# }

# output "compartment_defined_tags" {
#   description = "The defined tags of the compartment"
#   value       = module.compartment.compartment_defined_tags
# }
