output "argocd_url" {
  description = "ArgoCD UI URL."
  value       = "https://${local.argocd_fqdn}"
}

output "ingress_reserved_ip" {
  description = "Reserved public IP attached to the Traefik NLB."
  value       = data.terraform_remote_state.infra.outputs.ingress_reserved_ip
}

output "argocd_admin_hint" {
  description = "How to log in to ArgoCD."
  value       = "Login at https://${local.argocd_fqdn} as 'admin' with the password whose bcrypt hash is stored in the OCI Vault secret 'argocd-admin-password-bcrypt' (ddyyconsulting), synced into argocd-secret by External Secrets."
}

output "gitops_deploy_public_key" {
  description = "Public half of the TF-generated deploy key. Add this to langburd/gitops → Settings → Deploy keys (read-only)."
  value       = tls_private_key.deploy.public_key_openssh
}
