# output "test_compartment_id" {
#   description = "The root compartment ID of the Test Compartment"
#   value       = module.compartment.root_compartment_id
# }

output "oci_profile_data" {
  description = "The data from the OCI profile"
  sensitive   = true
  value       = module.oci_profile_reader.oci_profile_data
}
