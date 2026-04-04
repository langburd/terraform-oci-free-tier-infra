output "dev_compartment_id" {
  description = "The OCID of the Dev compartment"
  value       = module.dev_compartment.compartment_id
}

output "oci_profile_data" {
  description = "The data from the OCI profile"
  sensitive   = true
  value       = module.oci_profile_reader.oci_profile_data
}
