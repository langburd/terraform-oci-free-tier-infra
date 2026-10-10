# Certificate → produces the argocd-tls Secret in the TRAEFIK namespace.
# Gateway listener certificateRefs resolve Secrets in the Gateway's own
# namespace, so the cert must co-locate with Traefik to avoid a ReferenceGrant.
resource "kubernetes_manifest" "argocd_certificate" {
  depends_on = [kubernetes_manifest.letsencrypt_issuer]

  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "argocd-tls"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      dnsNames = [local.argocd_fqdn]
      issuerRef = {
        kind = "ClusterIssuer"
        name = "letsencrypt-cloudflare"
      }
      secretName = local.cert_secret_name
    }
  }
}
