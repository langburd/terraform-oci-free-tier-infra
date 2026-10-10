# HTTPRoute: argocd.ddyy.pro -> argocd-server (port 80, insecure; TLS ends at Traefik).
resource "kubernetes_manifest" "argocd_httproute" {
  depends_on = [helm_release.argocd, helm_release.traefik, kubernetes_manifest.argocd_ipallow]

  # Suppress plan churn on server-defaulted fields.
  #
  # WARNING: "spec.rules" is computed, so the provider ignores config changes under
  # it — edits to matches/filters/backendRefs produce NO diff. After changing them
  # (including this filter block), force recreation once:
  #   tofu apply -replace=kubernetes_manifest.argocd_httproute
  # Then confirm:
  #   kubectl -n argocd get httproute argocd -o yaml
  computed_fields = ["metadata.labels", "metadata.annotations", "spec.rules"]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd"
      namespace = local.namespaces.argocd
    }
    spec = {
      hostnames = [local.argocd_fqdn]
      parentRefs = [{
        name        = local.traefik_gateway_name
        namespace   = local.namespaces.traefik
        sectionName = "websecure"
      }]
      rules = [{
        backendRefs = [{ name = "argocd-server", port = 80 }]
        filters = [{
          extensionRef = {
            group = "traefik.io"
            kind  = "Middleware"
            # Literal, not a resource reference: argocd_ipallow.manifest carries the
            # sensitive CIDR list and referencing into it would taint this manifest.
            name = "argocd-ipallow"
          }
          type = "ExtensionRef"
        }]
        matches = [{ path = { type = "PathPrefix", value = "/" } }]
      }]
    }
  }
}
