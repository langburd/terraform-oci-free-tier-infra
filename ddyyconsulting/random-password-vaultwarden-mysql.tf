# MySQL HeatWave's password policy (and the mysql module) need upper, lower, digit and a
# special character. "-_." are URL-unreserved, so the app password goes into
# Vaultwarden's DATABASE_URL without encoding.
resource "random_password" "vaultwarden_mysql_admin" {
  length           = 32
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "-_."
}

resource "random_password" "vaultwarden_mysql_app" {
  length           = 32
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "-_."
}
