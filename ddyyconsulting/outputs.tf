output "dev_compartment_id" {
  description = "The root compartment ID of the Dev Compartment"
  value       = module.dev_compartment.root_compartment_id
}

output "oci_profile_data" {
  description = "The data from the OCI profile"
  sensitive   = true
  value       = module.oci_profile_reader.oci_profile_data
}
