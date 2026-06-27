# --- OCI flexible Load Balancer (free tier: min=max=10 Mbps) ---
service:
  annotations:
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"

# --- Gateway API provider (production-ready since Traefik v3.1) ---
providers:
  kubernetesGateway:
    enabled: true
  kubernetesIngress:
    enabled: false

# --- Chart-managed Gateway: HTTP + HTTPS listeners ---
gateway:
  enabled: true
  listeners:
    web:
      port: 80
      namespacePolicy:
        from: All
    websecure:
      port: 443
      protocol: HTTPS
      hostname: "${argocd_fqdn}"
      namespacePolicy:
        from: All
      certificateRefs:
        - name: "${cert_secret_name}"

# Single replica for free tier.
deployment:
  replicas: 1
