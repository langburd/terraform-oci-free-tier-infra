locals {
  # Confirmed in Task 4 — Traefik chart names the Gateway after the release ("traefik")
  # and its listeners "web" / "websecure". Override here if the kubectl check differs.
  traefik_gateway_name = "traefik-gateway"
}

# Per-FQDN IP allowlist, origin-side half (the edge half is waf.tf). Gateway API has
# no core IP filter, so this is a Traefik Middleware attached to the argocd HTTPRoute
# via an ExtensionRef filter below. ExtensionRef carries no namespace field -> the
# Middleware MUST live in the same namespace as the HTTPRoute referencing it.
# Non-matching clients get 403.
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
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "argocd-ipallow"
      namespace = local.namespaces.argocd
    }
    spec = {
      ipAllowList = {
        sourceRange = var.argocd_client_cidrs
        ipStrategy  = { depth = 1 }
      }
    }
  }
  computed_fields = ["metadata.labels", "metadata.annotations"]
  # helm_release.traefik for the Middleware CRD; kubernetes_namespace.argocd because
  # local.namespaces.argocd is a literal string and creates no implicit dependency —
  # without it a fresh apply can fail with `namespaces "argocd" not found`.
  depends_on = [helm_release.traefik, kubernetes_namespace.argocd]
}

# HTTPRoute: argocd.ddyy.pro -> argocd-server (port 80, insecure; TLS ends at Traefik).
resource "kubernetes_manifest" "argocd_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd"
      namespace = local.namespaces.argocd
    }
    spec = {
      parentRefs = [{
        name        = local.traefik_gateway_name
        namespace   = local.namespaces.traefik
        sectionName = "websecure"
      }]
      hostnames = [local.argocd_fqdn]
      rules = [{
        matches = [{ path = { type = "PathPrefix", value = "/" } }]
        filters = [{
          type = "ExtensionRef"
          extensionRef = {
            group = "traefik.io"
            kind  = "Middleware"
            # Literal, not a resource reference: argocd_ipallow.manifest carries the
            # sensitive CIDR list and referencing into it would taint this manifest.
            name = "argocd-ipallow"
          }
        }]
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  }
  # Suppress plan churn on server-defaulted fields.
  #
  # WARNING: "spec.rules" is computed, so the provider ignores config changes under
  # it — edits to matches/filters/backendRefs produce NO diff. After changing them
  # (including this filter block), force recreation once:
  #   tofu apply -replace=kubernetes_manifest.argocd_httproute
  # Then confirm:
  #   kubectl -n argocd get httproute argocd -o yaml
  computed_fields = ["metadata.labels", "metadata.annotations", "spec.rules"]
  depends_on      = [helm_release.argocd, helm_release.traefik, kubernetes_manifest.argocd_ipallow]
}

# HTTPRoute: native Gateway API HTTP->HTTPS 301 redirect on the :80 (web) listener.
resource "kubernetes_manifest" "argocd_http_redirect" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd-redirect"
      namespace = local.namespaces.argocd
    }
    spec = {
      parentRefs = [{
        name        = local.traefik_gateway_name
        namespace   = local.namespaces.traefik
        sectionName = "web"
      }]
      hostnames = [local.argocd_fqdn]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            port       = 443
            statusCode = 301
          }
        }]
      }]
    }
  }
  computed_fields = ["metadata.labels", "metadata.annotations", "spec.rules"]
  depends_on      = [helm_release.traefik]
}

# --- TF-generated read-only SSH deploy key (public half exported in outputs.tf) ---
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

# --- ArgoCD repository Secret (SSH) ---
resource "kubernetes_secret" "gitops_repo" {
  metadata {
    name      = "gitops-repo"
    namespace = local.namespaces.argocd
    labels    = { "argocd.argoproj.io/secret-type" = "repository" }
  }
  data = {
    type          = "git"
    url           = local.gitops_repo_url
    sshPrivateKey = tls_private_key.deploy.private_key_openssh
  }
  type       = "Opaque"
  depends_on = [helm_release.argocd]
}

# --- Root Application (app-of-apps) ---
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = local.namespaces.argocd
    }
    spec = {
      project = "default"
      source = {
        repoURL        = local.gitops_repo_url
        path           = local.gitops_repo_path
        targetRevision = local.gitops_repo_branch
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.namespaces.argocd
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  depends_on      = [kubernetes_secret.gitops_repo]
}
