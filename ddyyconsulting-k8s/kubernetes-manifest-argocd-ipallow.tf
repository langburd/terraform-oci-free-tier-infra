# Per-FQDN IP allowlist, origin-side half (the edge half is
# cloudflare-ruleset-zone-firewall-custom.tf). Gateway API has no core IP filter, so
# this is a Traefik Middleware attached to the argocd HTTPRoute via an ExtensionRef
# filter below. ExtensionRef carries no namespace field -> the Middleware MUST live
# in the same namespace as the HTTPRoute referencing it. Non-matching clients get 403.
#
# ipStrategy.depth is mandatory here: the DNS record is Cloudflare-proxied, so the
# connection's source IP is always a Cloudflare edge IP. depth = 1 reads the
# rightmost X-Forwarded-For entry, which is the IP Cloudflare itself observed —
# anything a client prepends to XFF sits to the left of it and cannot spoof this.
# Requires forwardedHeaders.trustedIPs (Cloudflare ranges) on the websecure
# entrypoint, else Traefik discards the inbound XFF header.
#
# Verify from an allowed host (expect 200) and a non-allowed one (expect 403):
#   curl -s -o /dev/null -w '%{http_code}\n' https://argocd.ddyy.pro/
# If everything 403s, the depth is off by one for this Traefik version — check what
# the middleware actually saw (access logs are enabled in the Traefik values):
#   kubectl -n traefik logs deploy/traefik | tail -20
resource "kubernetes_manifest" "argocd_ipallow" {
  # helm_release.traefik for the Middleware CRD; kubernetes_namespace_v1.argocd because
  # local.namespaces.argocd is a literal string and creates no implicit dependency —
  # without it a fresh apply can fail with `namespaces "argocd" not found`.
  depends_on = [helm_release.traefik, kubernetes_namespace_v1.argocd]

  computed_fields = ["metadata.labels", "metadata.annotations"]
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "argocd-ipallow"
      namespace = local.namespaces.argocd
    }
    spec = {
      ipAllowList = {
        ipStrategy  = { depth = 1 }
        sourceRange = var.argocd_client_cidrs
      }
    }
  }
}
