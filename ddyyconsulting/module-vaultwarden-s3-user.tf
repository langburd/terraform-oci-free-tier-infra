# S3-compatible key for Vaultwarden and the off-site backup CronJob: objects in the data
# bucket only. Identity-domain tenancies give users an email; plus-addressing keeps it
# unique.
module "vaultwarden_s3_user" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/s3_access_user/v1.0.0"

  bucket_names   = [module.vaultwarden_data_bucket.bucket_name]
  compartment_id = module.dev_compartment.compartment_id
  description    = "Vaultwarden S3-compatible access to its data bucket."
  email          = "avi+vaultwarden-s3@langburd.com"
  freeform_tags  = local.default_tags
  name           = "vaultwarden-s3"
  tenancy_id     = module.oci_profile_reader.oci_profile_data.tenancy
}
