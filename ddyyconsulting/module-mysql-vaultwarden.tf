data "oci_identity_availability_domains" "this" {
  compartment_id = module.oci_profile_reader.oci_profile_data.tenancy
}

# MySQL HeatWave Always Free (one per tenancy, home region only) for Vaultwarden.
# Standalone, 1-day automatic backups, no PITR; the off-site R2 copy (langburd/gitops
# addons/vaultwarden) is the long-term backup. Delete protection plus a required final
# backup stand in for prevent_destroy, which a module input cannot carry: to delete,
# set is_delete_protected = false and apply first.
module "mysql_vaultwarden" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/mysql/v2.2.0"

  admin_password              = random_password.vaultwarden_mysql_admin.result
  admin_username              = "admin"
  automatic_backup_retention  = "RETAIN"
  availability_domain         = data.oci_identity_availability_domains.this.availability_domains[0].name
  certificate_generation_type = "BYOC"
  certificate_id              = module.vaultwarden_mysql_certificates.certificate_id
  compartment_id              = module.dev_compartment.compartment_id
  final_backup                = "REQUIRE_FINAL_BACKUP"
  hostname_label              = local.vaultwarden_db_hostname
  is_delete_protected         = true
  # Weekly window; OCI also upgrades the MySQL version in it. Sunday 02:00 UTC.
  maintenance_window_start_time = "sun 02:00"
  mysql_display_name            = "vaultwarden-mysql"
  mysql_freeform_tags           = local.default_tags
  nsg_ids                       = [module.mysql_nsg.nsg_id]
  shape_name                    = "MySQL.Free"
  subnet_id                     = module.db_subnet.subnet_id
}
