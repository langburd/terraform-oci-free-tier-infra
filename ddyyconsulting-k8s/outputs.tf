output "argocd_url" {
  description = "ArgoCD UI URL."
  value       = "https://${var.argocd_fqdn}"
}

output "traefik_lb_ip" {
  description = "Public IP of the OCI Load Balancer fronting Traefik."
  value       = local.traefik_lb_ip
}

output "argocd_admin_hint" {
  description = "How to log in to ArgoCD."
  value       = "Login at https://${var.argocd_fqdn} as 'admin' with the password whose bcrypt hash was supplied via argocd_admin_password_bcrypt."
}

output "gitops_deploy_public_key" {
  description = "Public half of the TF-generated deploy key. Add this to langburd/gitops → Settings → Deploy keys (read-only)."
  value       = tls_private_key.deploy.public_key_openssh
}
