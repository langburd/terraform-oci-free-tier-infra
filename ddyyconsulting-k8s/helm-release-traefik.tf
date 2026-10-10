resource "helm_release" "traefik" {
  # Cert Secret (in traefik ns) must exist before the HTTPS listener validates.
  depends_on = [kubernetes_manifest.argocd_certificate]

  atomic      = true
  chart       = "traefik"
  max_history = 5
  name        = "traefik"
  namespace   = kubernetes_namespace_v1.traefik.metadata[0].name
  repository  = "https://traefik.github.io/charts"
  timeout     = 600
  values = [
    templatefile("${path.module}/helm-values/traefik/values.yaml.tpl", {
      argocd_fqdn = local.argocd_fqdn
      # JSON is valid YAML flow syntax, which sidesteps block-list indentation
      # inside the template.
      cf_ipv4_cidrs_json = jsonencode(data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs)
      cert_secret_name   = local.cert_secret_name
      lb_nsg_id          = local.lb_nsg_id
    })
  ]
  version = local.chart_versions.traefik
}
