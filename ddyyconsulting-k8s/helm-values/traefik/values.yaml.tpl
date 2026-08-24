# --- OCI flexible Load Balancer (free tier: min=max=10 Mbps) ---
service:
  annotations:
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"

# --- Entrypoints: high internal ports (non-root can bind), LB maps 80->9080 / 443->8443.
#     8080 is reserved by Traefik's built-in dashboard entrypoint — do NOT use it for web. ---
ports:
  web:
    port: 9080
    expose:
      default: true
    exposedPort: 80
  websecure:
    port: 8443
    expose:
      default: true
    exposedPort: 443

# --- Gateway API provider (production-ready since Traefik v3.1) ---
providers:
  kubernetesGateway:
    enabled: true
  kubernetesIngress:
    enabled: false

# --- Chart-managed Gateway: listeners reference internal (high) ports ---
gateway:
  enabled: true
  listeners:
    web:
      port: 9080
      namespacePolicy:
        from: All
    websecure:
      port: 8443
      protocol: HTTPS
      hostname: "${argocd_fqdn}"
      namespacePolicy:
        from: All
      certificateRefs:
        - name: "${cert_secret_name}"

# Non-root, no NET_BIND_SERVICE needed (binds high ports 8080/8443).
securityContext:
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true

# Single replica for free tier.
deployment:
  replicas: 1
