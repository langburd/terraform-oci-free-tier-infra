# Root Application (app-of-apps).
resource "kubernetes_manifest" "app_of_apps" {
  depends_on = [kubernetes_secret_v1.gitops_repo]

  computed_fields = ["metadata.labels", "metadata.annotations", "status"]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = local.namespaces.argocd
    }
    spec = {
      destination = {
        namespace = local.namespaces.argocd
        server    = "https://kubernetes.default.svc"
      }
      project = "default"
      source = {
        path           = local.gitops_repo_path
        repoURL        = local.gitops_repo_url
        targetRevision = local.gitops_repo_branch
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
}
