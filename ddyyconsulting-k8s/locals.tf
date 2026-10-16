locals {
  # Bastion tunnel endpoint (operator runs the port-forward before apply).
  k8s_host = "https://127.0.0.1:6443"

  cluster_id = data.terraform_remote_state.infra.outputs.oke_cluster_id

  # NSG holding the public LB 80/443 ingress allowlist (Cloudflare's edge ranges).
  # The OCI CCM manages security rules for LBaaS but NOT for NLBs, so the NSG has to
  # be attached explicitly through a Service annotation (set by the traefik addon in langburd/gitops).
  lb_nsg_id = data.terraform_remote_state.infra.outputs.oke_lb_nsg_id

  # Fixed, non-secret configuration for this environment. Secrets stay as
  # sensitive variables (see variables.tf) and are supplied via TF_VAR_*.
  acme_email           = "alerts@ddyy.pro"
  argocd_fqdn          = "argocd.ddyy.pro"
  cloudflare_zone_name = "ddyy.pro"

  # GitOps repo the ArgoCD root app-of-apps tracks. url MUST be scp-style SSH
  # (git@host:org/repo.git) — ArgoCD matches the SSH key only against that form.
  gitops_repo_branch = "master"
  gitops_repo_path   = "bootstrap"
  gitops_repo_url    = "git@github.com:langburd/gitops.git"

  namespaces = {
    argocd = "argocd"
  }

  chart_versions = {
    argocd = "10.10.5" # confirm: helm search repo argo/argo-cd
  }
}
