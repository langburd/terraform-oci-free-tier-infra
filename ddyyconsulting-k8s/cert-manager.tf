resource "helm_release" "cert_manager" {
  name        = "cert-manager"
  namespace   = kubernetes_namespace.cert_manager.metadata[0].name
  repository  = "https://charts.jetstack.io"
  chart       = "cert-manager"
  version     = local.chart_versions.cert_manager
  atomic      = true # roll back on failed install
  max_history = 5
  timeout     = 600

  values = [
    templatefile("${path.module}/helm-values/cert-manager/values.yaml.tpl", {})
  ]
}

# Cloudflare API token Secret for the DNS-01 solver.
resource "kubernetes_secret" "cloudflare_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }
  data = { api-token = var.certmanager_cf_token }
  type = "Opaque"
}

# ClusterIssuer (Let's Encrypt production, DNS-01 via Cloudflare).
resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-cloudflare" }
    spec = {
      acme = {
        server              = "https://acme-v02.api.letsencrypt.org/directory"
        email               = local.acme_email
        privateKeySecretRef = { name = "letsencrypt-cloudflare-account-key" }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = kubernetes_secret.cloudflare_token.metadata[0].name
                key  = "api-token"
              }
            }
          }
          selector = { dnsZones = [local.cloudflare_zone_name] }
        }]
      }
    }
  }
  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  depends_on      = [helm_release.cert_manager]
}

# Certificate → produces the argocd-tls Secret in the TRAEFIK namespace.
# Gateway listener certificateRefs resolve Secrets in the Gateway's own
# namespace, so the cert must co-locate with Traefik to avoid a ReferenceGrant.
resource "kubernetes_manifest" "argocd_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "argocd-tls"
      namespace = kubernetes_namespace.traefik.metadata[0].name
    }
    spec = {
      secretName = local.cert_secret_name
      dnsNames   = [local.argocd_fqdn]
      issuerRef = {
        name = "letsencrypt-cloudflare"
        kind = "ClusterIssuer"
      }
    }
  }
  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  depends_on      = [kubernetes_manifest.letsencrypt_issuer]
}
