global:
  domain: "${argocd_fqdn}"

configs:
  params:
    # TLS terminates at Traefik; argocd-server runs insecure (cluster-internal hop).
    server.insecure: true
  secret:
    # Bcrypt hash of the admin password.
    argocdServerAdminPassword: "${admin_password_hash}"
    # Mtime MUST be set or ArgoCD ignores the configured hash. Use a FIXED timestamp
    # (var, not a TF function) so it does not change every apply and reset the password.
    argocdServerAdminPasswordMtime: "${admin_password_mtime}"

# Single replica everything (free tier).
controller:
  replicas: 1
server:
  replicas: 1
repoServer:
  replicas: 1
