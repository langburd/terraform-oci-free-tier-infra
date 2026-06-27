locals {
  # Confirmed in Task 4 — Traefik chart names the Gateway after the release ("traefik")
  # and its listeners "web" / "websecure". Override here if the kubectl check differs.
  traefik_gateway_name = "traefik"
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
      hostnames = [var.argocd_fqdn]
      rules = [{
        matches     = [{ path = { type = "PathPrefix", value = "/" } }]
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  }
  # Suppress plan churn on server-defaulted fields.
  computed_fields = ["metadata.labels", "metadata.annotations", "spec.rules"]
  depends_on      = [helm_release.argocd, helm_release.traefik]
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
      hostnames = [var.argocd_fqdn]
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
    url           = var.gitops_repo_url
    sshPrivateKey = tls_private_key.deploy.private_key_openssh
  }
  type       = "Opaque"
  depends_on = [helm_release.argocd]
}

# --- Root Application (app-of-apps) ---
resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = local.namespaces.argocd
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        path           = var.gitops_repo_path
        targetRevision = var.gitops_repo_branch
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
