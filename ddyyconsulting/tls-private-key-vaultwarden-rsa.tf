# JWT signing key shared by every Vaultwarden replica (RSA_KEY_FILENAME), so a token
# issued by one pod validates on the other.
resource "tls_private_key" "vaultwarden_rsa" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
