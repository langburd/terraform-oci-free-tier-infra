# Cloudflare API token Secret for the DNS-01 solver.
resource "kubernetes_secret_v1" "cloudflare_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }
  data = { api-token = var.certmanager_cf_token }
  type = "Opaque"
}
