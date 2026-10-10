resource "helm_release" "cert_manager" {
  atomic      = true # roll back on failed install
  chart       = "cert-manager"
  max_history = 5
  name        = "cert-manager"
  namespace   = kubernetes_namespace_v1.cert_manager.metadata[0].name
  repository  = "https://charts.jetstack.io"
  timeout     = 600
  values = [
    templatefile("${path.module}/helm-values/cert-manager/values.yaml.tpl", {})
  ]
  version = local.chart_versions.cert_manager
}
