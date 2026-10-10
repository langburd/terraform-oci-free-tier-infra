locals {
  # Bastion tunnel endpoint (operator runs the port-forward before apply).
  k8s_host = "https://127.0.0.1:6443"

  cluster_id = data.terraform_remote_state.infra.outputs.oke_cluster_id

  # NSG holding the public LB 80/443 ingress allowlist (Cloudflare's edge ranges).
  # The OCI CCM manages security rules for LBaaS but NOT for NLBs, so the NSG has to
  # be attached explicitly through a Service annotation — see the traefik values.
  lb_nsg_id = data.terraform_remote_state.infra.outputs.oke_lb_nsg_id

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

  # Confirmed in Task 4 — Traefik chart names the Gateway after the release ("traefik")
  # and its listeners "web" / "websecure". Override here if the kubectl check differs.
  traefik_gateway_name = "traefik-gateway"
}
