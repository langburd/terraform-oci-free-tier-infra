# ArgoCD cluster Secret: drives the addon ApplicationSets in langburd/gitops.
# Label and annotation keys mirror clusters/ddyy-oke/cluster.yaml (spec §4).
resource "kubernetes_secret_v1" "argocd_cluster_ddyy_oke" {
  depends_on = [helm_release.argocd]

  data = {
    config = jsonencode({ tlsClientConfig = { insecure = false } })
    name   = "ddyy-oke"
    server = "https://kubernetes.default.svc"
  }
  metadata {
    annotations = {
      acme_email                   = local.acme_email
      addons_autosync              = "true" # "false" = review `argocd app diff` before syncing
      addons_repo_revision         = "HEAD"
      addons_repo_url              = local.gitops_repo_url
      argocd_client_cidrs          = jsonencode(var.argocd_client_cidrs)
      argocd_fqdn                  = local.argocd_fqdn
      cert_manager_extra_zones     = jsonencode(local.cert_manager_extra_zones)
      cloudflare_zone_name         = local.cloudflare_zone_name
      eso_auth                     = "instance"
      lb_nsg_id                    = local.lb_nsg_id
      lb_reserved_ip               = data.terraform_remote_state.infra.outputs.ingress_reserved_ip
      oci_objectstorage_namespace  = data.terraform_remote_state.infra.outputs.oci_objectstorage_namespace
      oci_region                   = data.terraform_remote_state.infra.outputs.oci_region
      oci_vault_id                 = data.terraform_remote_state.infra.outputs.vault_id
      offsite_backup_age_recipient = var.offsite_backup_age_recipient
      offsite_backup_bucket        = cloudflare_r2_bucket.vaultwarden_offsite.name
      offsite_backup_endpoint      = local.r2_endpoint
      trusted_proxy_cidrs          = jsonencode(data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs)
      vaultwarden_data_bucket      = data.terraform_remote_state.infra.outputs.vaultwarden_data_bucket
      vaultwarden_db_host          = data.terraform_remote_state.infra.outputs.vaultwarden_db_host
      vaultwarden_fqdn             = local.vaultwarden_fqdn
    }
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      cloud                            = "oci"
      enable_argocd                    = "true"
      enable_cert_manager              = "true"
      enable_external_secrets          = "true"
      enable_metrics_server            = "true"
      enable_traefik                   = "true"
      enable_vaultwarden               = "true"
    }
    name      = "ddyy-oke"
    namespace = local.namespaces.argocd
  }
  type = "Opaque"
}
