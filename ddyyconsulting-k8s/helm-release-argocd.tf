resource "helm_release" "argocd" {
  depends_on = [kubernetes_namespace_v1.argocd]

  atomic      = true
  chart       = "argo-cd"
  max_history = 5
  name        = "argocd"
  namespace   = local.namespaces.argocd
  repository  = "https://argoproj.github.io/argo-helm"
  timeout     = 1200 # ArgoCD is slow to settle (CRDs + multiple deployments)
  values = [
    templatefile("${path.module}/helm-values/argocd/values.yaml.tpl", {
      admin_password_hash  = var.argocd_admin_password_bcrypt
      admin_password_mtime = var.argocd_admin_password_mtime
      argocd_fqdn          = local.argocd_fqdn
    })
  ]
  version = local.chart_versions.argocd
}
