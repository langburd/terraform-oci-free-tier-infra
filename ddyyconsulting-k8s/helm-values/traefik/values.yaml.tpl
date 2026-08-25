# --- OCI Network Load Balancer ---
# NLB, not the flexible LBaaS: LBaaS proxies TCP and rewrites the source IP, so
# Traefik could not tell a Cloudflare edge connection from any other. NLB preserves
# it, which forwardedHeaders.trustedIPs below depends on. NLB is also free of
# charge, leaving the free-tier flexible LB allowance unused.
# Switching type recreates the LB, so the public IP changes — dns.tf re-reads it
# from the Service status and re-applies the Cloudflare A record.
#
# CHANGING TYPE IS NOT AN IN-PLACE UPGRADE: the OCI CCM cannot convert an existing
# LBaaS Service into an NLB. On an already-deployed cluster, delete the Service (or
# `helm uninstall traefik`) once so the CCM tears down the old LBaaS and provisions
# the NLB from scratch. Skipping this leaves the LBaaS in place — it still proxies and
# rewrites the source IP, so trustedIPs below never matches and every request 403s.
service:
  annotations:
    oci.oraclecloud.com/load-balancer-type: "nlb"
    # The CCM manages security list rules for LBaaS but NOT for NLBs, so without this
    # nothing permits Cloudflare -> LB:80/443 and the edge gets a 522. The NSG is
    # created in ../ddyyconsulting (module "lb_nsg") and its rules are scoped to
    # Cloudflare's ranges plus var.lb_extra_ingress_cidrs.
    oci-network-load-balancer.oraclecloud.com/network-security-group-ids: "${lb_nsg_id}"
  spec:
    # Mandatory: with the default "Cluster" policy kube-proxy SNATs incoming
    # packets and Traefik sees a node IP, so no connection would ever match
    # trustedIPs and every inbound X-Forwarded-For would be discarded.
    # Side effect: only nodes running a Traefik pod are healthy NLB backends,
    # which is why replicas below matches the node count.
    externalTrafficPolicy: Local
    # NOTE: loadBalancerSourceRanges is deliberately NOT set here. The OCI CCM
    # silently ignores it for NLBs — it creates no NSG on the load balancer and
    # writes no security list rule, so it reads as a lockdown while enforcing
    # nothing. The origin is locked down in ../ddyyconsulting instead, via
    # worker_nsg ingress rules scoped to Cloudflare's ranges.

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
    # Trust X-Forwarded-For only from Cloudflare edge IPs. Without this Traefik
    # overwrites the inbound XFF with the peer address and the ipAllowList
    # Middleware's ipStrategy.depth has nothing real to read. With it, any XFF
    # from a non-Cloudflare peer is still discarded, so a direct-to-origin caller
    # cannot forge an allowlisted client IP.
    forwardedHeaders:
      trustedIPs: ${cf_ipv4_cidrs_json}

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

# Access logs on: without them a 403 from the ipAllowList Middleware is
# indistinguishable from a 403 elsewhere, and the observed client IP is unknowable.
logs:
  access:
    enabled: true

# One replica per worker node. Under externalTrafficPolicy: Local a node is only a
# healthy NLB backend while it runs a Traefik pod, so this is what makes both NLB
# backends healthy and removes the single point of failure. Safe here only because
# TLS certs come from cert-manager Secrets, not Traefik's own ACME resolver — a
# file-based acme.json has a single-writer constraint and would corrupt with >1
# replica. Keep in sync with var.node_count in ../ddyyconsulting (2).
deployment:
  replicas: 2

# Guarantee one pod per node; co-locating both would leave a node without a local
# endpoint and its NLB backend CRITICAL, defeating the second replica.
# maxSkew 1 (not required podAntiAffinity) is deliberate: the default rollout is
# maxSurge 1 / maxUnavailable 0, so an update briefly needs 3 pods on 2 nodes.
# Anti-affinity would leave the surge pod Pending forever and deadlock the rollout;
# a 2/1 split is within maxSkew 1, so this permits it and still converges to 1/1.
# nodeTaintsPolicy: Honor drops a cordoned node from the domain count, so
# `kubectl drain` can move the pod to the surviving node instead of hanging.
topologySpreadConstraints:
  - labelSelector:
      matchLabels:
        app.kubernetes.io/name: traefik
    maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    nodeTaintsPolicy: Honor

# Stops a drain or eviction taking both replicas at once (which is a full outage,
# not a degraded one, since every NLB backend would lose its local endpoint).
podDisruptionBudget:
  enabled: true
  minAvailable: 1
