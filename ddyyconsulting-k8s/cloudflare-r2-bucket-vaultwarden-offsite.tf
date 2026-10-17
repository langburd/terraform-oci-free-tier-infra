locals {
  cloudflare_account_id = data.cloudflare_zone.this.account.id
  r2_endpoint           = "https://${local.cloudflare_account_id}.r2.cloudflarestorage.com"
}

# Off-site copy of Vaultwarden (nightly age-encrypted DB dump + attachments), outside OCI
# so it survives losing the OCI account. Written by the vaultwarden-offsite-backup CronJob
# in langburd/gitops with a bucket-scoped R2 API token (see docs/cloudflare-tokens.md).
resource "cloudflare_r2_bucket" "vaultwarden_offsite" {
  account_id = local.cloudflare_account_id
  location   = "eeur"
  name       = "ddyy-vaultwarden-offsite"
}

# Keep 90 days of archives; clean up abandoned multipart uploads after a day.
resource "cloudflare_r2_bucket_lifecycle" "vaultwarden_offsite" {
  account_id  = local.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.vaultwarden_offsite.name

  rules = [{
    id         = "expire-after-90-days"
    enabled    = true
    conditions = { prefix = "" }
    abort_multipart_uploads_transition = {
      condition = { type = "Age", max_age = 86400 }
    }
    delete_objects_transition = {
      condition = { type = "Age", max_age = 7776000 }
    }
  }]
}

# Objects cannot be deleted or overwritten for 30 days, even with the bucket's own
# credentials: a leaked or misused key cannot wipe recent backups.
resource "cloudflare_r2_bucket_lock" "vaultwarden_offsite" {
  account_id  = local.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.vaultwarden_offsite.name

  rules = [{
    id        = "retain-30-days"
    enabled   = true
    condition = { type = "Age", max_age_seconds = 2592000 }
  }]
}
