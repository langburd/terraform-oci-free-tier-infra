# Vaultwarden DATA_FOLDER (attachments, sends) via the S3-compatible endpoint.
# Versioned; old versions are deleted after 30 days. OCI refuses to delete a bucket that
# still holds objects or versions, which guards against an accidental destroy.
module "vaultwarden_data_bucket" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/object_storage/v2.1.0"

  bucket_freeform_tags            = local.default_tags
  bucket_name                     = "ddyy-vaultwarden-data"
  compartment_id                  = module.dev_compartment.compartment_id
  previous_version_retention_days = 30
  region                          = local.region
  versioning                      = "Enabled"
}
