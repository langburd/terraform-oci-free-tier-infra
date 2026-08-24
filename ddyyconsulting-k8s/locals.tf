# Cluster CA is not exported by the OKE module, so derive it from the cluster's
# kube-config at apply time (Task 1 fallback path). The kube-config carries the
# base64 CA in clusters[0].cluster["certificate-authority-data"].
data "oci_containerengine_cluster_kube_config" "this" {
  cluster_id = local.cluster_id
}

locals {
  # Bastion tunnel endpoint (operator runs the port-forward before apply).
  k8s_host = "https://127.0.0.1:6443"

  cluster_ca = yamldecode(data.oci_containerengine_cluster_kube_config.this.content)["clusters"][0]["cluster"]["certificate-authority-data"]
  cluster_id = data.terraform_remote_state.infra.outputs.oke_cluster_id

  # Fixed, non-secret configuration for this environment. Secrets stay as
  # sensitive variables (see variables.tf) and are supplied via TF_VAR_*.
  acme_email           = "alerts@ddyy.pro"
  argocd_fqdn          = "argocd.ddyy.pro"
  cloudflare_zone_name = "ddyy.pro"

  # GitOps repo the ArgoCD root app-of-apps tracks. url MUST be scp-style SSH
  # (git@host:org/repo.git) — ArgoCD matches the SSH key only against that form.
  gitops_repo_branch = "master"
  gitops_repo_path   = "apps"
  gitops_repo_url    = "git@github.com:langburd/gitops.git"

  namespaces = {
    argocd       = "argocd"
    cert_manager = "cert-manager"
    traefik      = "traefik"
  }

  chart_versions = {
    argocd       = "10.0.0"  # confirm: helm search repo argo/argo-cd
    cert_manager = "v1.18.2" # confirm: helm search repo jetstack/cert-manager
    traefik      = "37.0.0"  # confirm latest at apply: helm search repo traefik/traefik
  }

  cert_secret_name = "argocd-tls"
}
