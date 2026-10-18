locals {
  # <hostname_label>.<db subnet dns_label>.<VCN dns_label>.oraclevcn.com
  vaultwarden_db_fqdn = "vaultwarden-mysql.db.k8svcn.oraclevcn.com"
}

# Private CA plus a server certificate for the Vaultwarden MySQL endpoint (BYOC). The SYSTEM
# certificate has no SAN, which Vaultwarden's MariaDB connector rejects. Clients pin the CA,
# so leaf renewals do not break them. Validity dates are fixed (the module defaults use
# plantimestamp and would diff on every plan); the CA outlives the leaf by 9 years.
# The Certificates API rejects timestamps without fractional seconds and the provider drops `.000`, hence `.001`.
module "vaultwarden_mysql_certificates" {
  source = "git@github.com:langburd/terraform-oci-free-tier-modules.git?ref=oci/certificates/v2.1.0"
  # source = "../../terraform-oci-free-tier-modules/oci/certificates"

  ca_common_name                         = "vaultwarden-mysql-ca"
  ca_name                                = "vaultwarden-mysql-ca"
  ca_validity_time_of_validity_not_after = "2036-10-18T00:00:00.001Z"
  certificate_common_name                = local.vaultwarden_db_fqdn
  certificate_key_algorithm              = "RSA2048"
  certificate_name                       = "vaultwarden-mysql"
  certificate_profile_type               = "TLS_SERVER"
  # The renewal interval must not exceed the leaf validity period.
  certificate_renewal_rule                        = { renewal_interval = "P330D", advance_renewal_period = "P30D" }
  certificate_subject_alternative_names           = [{ type = "DNS", value = local.vaultwarden_db_fqdn }]
  certificate_validity_time_of_validity_not_after = "2027-10-18T00:00:00.001Z"
  certificates_freeform_tags                      = local.default_tags
  compartment_id                                  = module.dev_compartment.compartment_id
  create_certificate                              = true
  create_kms_policy                               = true
  kms_key_id                                      = module.vault_certificates.key_id
}
