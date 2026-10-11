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
      argocd_fqdn = local.argocd_fqdn
    })
  ]
  version = local.chart_versions.argocd

  # ArgoCD is self-managed by langburd/gitops addons/argocd; this release is install-once /
  # break-glass (`tofu apply -replace=helm_release.argocd`). The admin password is restored
  # by the ESO ExternalSecret (Merge into argocd-secret), not by these values.
  lifecycle {
    ignore_changes = all
  }
}
