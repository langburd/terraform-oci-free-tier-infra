# HTTPRoute: native Gateway API HTTP->HTTPS 301 redirect on the :80 (web) listener.
resource "kubernetes_manifest" "argocd_http_redirect" {
  depends_on = [helm_release.traefik]

  computed_fields = ["metadata.labels", "metadata.annotations", "spec.rules"]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd-redirect"
      namespace = local.namespaces.argocd
    }
    spec = {
      hostnames = [local.argocd_fqdn]
      parentRefs = [{
        name        = local.traefik_gateway_name
        namespace   = local.namespaces.traefik
        sectionName = "web"
      }]
      rules = [{
        filters = [{
          requestRedirect = {
            port       = 443
            scheme     = "https"
            statusCode = 301
          }
          type = "RequestRedirect"
        }]
      }]
    }
  }
}
