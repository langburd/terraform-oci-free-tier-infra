output "root_compartment_id" {
  description = "The root compartment ID"
  value       = module.compartment.root_compartment_id
}

output "oci_profile_data" {
  description = "The data from the OCI profile"
  value       = module.oci_profile_reader.oci_profile_data
}
