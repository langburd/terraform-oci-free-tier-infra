# Cloudflare API token Secret for the DNS-01 solver.
resource "kubernetes_secret_v1" "cloudflare_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }
  data = { api-token = var.certmanager_cf_token }
  type = "Opaque"
}

# ClusterIssuer (Let's Encrypt production, DNS-01 via Cloudflare).
resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [helm_release.cert_manager]

  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-cloudflare" }
    spec = {
      acme = {
        email               = local.acme_email
        privateKeySecretRef = { name = "letsencrypt-cloudflare-account-key" }
        server              = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                key  = "api-token"
                name = kubernetes_secret_v1.cloudflare_token.metadata[0].name
              }
            }
          }
          selector = { dnsZones = [local.cloudflare_zone_name] }
        }]
      }
    }
  }
}
