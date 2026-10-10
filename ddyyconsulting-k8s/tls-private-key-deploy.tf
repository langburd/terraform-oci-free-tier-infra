# TF-generated read-only SSH deploy key (public half exported in outputs.tf).
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}
