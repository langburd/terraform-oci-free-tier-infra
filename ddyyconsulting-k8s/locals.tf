# Cluster CA is not exported by the OKE module, so derive it from the cluster's
# kube-config at apply time (Task 1 fallback path). The kube-config carries the
# base64 CA in clusters[0].cluster["certificate-authority-data"].
data "oci_containerengine_cluster_kube_config" "this" {
  cluster_id = local.cluster_id
}

locals {
  # Bastion tunnel endpoint (operator runs the port-forward before apply).
  k8s_host = "https://127.0.0.1:6443"

  cluster_id = data.terraform_remote_state.infra.outputs.oke_cluster_id
  cluster_ca = yamldecode(data.oci_containerengine_cluster_kube_config.this.content)["clusters"][0]["cluster"]["certificate-authority-data"]

  namespaces = {
    traefik      = "traefik"
    cert_manager = "cert-manager"
    argocd       = "argocd"
  }

  chart_versions = {
    traefik      = "37.0.0"  # confirm latest at apply: helm search repo traefik/traefik
    cert_manager = "v1.18.2" # confirm: helm search repo jetstack/cert-manager
    argocd       = "10.0.0"  # confirm: helm search repo argo/argo-cd
  }

  cert_secret_name = "argocd-tls"
}
