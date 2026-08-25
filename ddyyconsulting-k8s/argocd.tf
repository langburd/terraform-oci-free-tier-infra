resource "helm_release" "argocd" {
  name        = "argocd"
  namespace   = local.namespaces.argocd
  repository  = "https://argoproj.github.io/argo-helm"
  chart       = "argo-cd"
  version     = local.chart_versions.argocd
  atomic      = true
  max_history = 5
  timeout     = 1200 # ArgoCD is slow to settle (CRDs + multiple deployments)

  values = [
    templatefile("${path.module}/helm-values/argocd/values.yaml.tpl", {
      argocd_fqdn          = local.argocd_fqdn
      admin_password_hash  = var.argocd_admin_password_bcrypt
      admin_password_mtime = var.argocd_admin_password_mtime
    })
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}
