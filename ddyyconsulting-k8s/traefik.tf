resource "helm_release" "traefik" {
  name        = "traefik"
  namespace   = kubernetes_namespace.traefik.metadata[0].name
  repository  = "https://traefik.github.io/charts"
  chart       = "traefik"
  version     = local.chart_versions.traefik
  atomic      = true
  max_history = 5
  timeout     = 600

  values = [
    templatefile("${path.module}/helm-values/traefik/values.yaml.tpl", {
      argocd_fqdn      = local.argocd_fqdn
      cert_secret_name = local.cert_secret_name
      # JSON is valid YAML flow syntax, which sidesteps block-list indentation
      # inside the template.
      cf_ipv4_cidrs_json = jsonencode(data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs)
    })
  ]

  # Cert Secret (in traefik ns) must exist before the HTTPS listener validates.
  depends_on = [kubernetes_manifest.argocd_certificate]
}
