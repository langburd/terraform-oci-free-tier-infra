global:
  domain: "${argocd_fqdn}"

configs:
  params:
    # TLS terminates at Traefik; argocd-server runs insecure (cluster-internal hop).
    server.insecure: true

# Single replica everything (free tier).
controller:
  replicas: 1
server:
  replicas: 1
repoServer:
  replicas: 1
