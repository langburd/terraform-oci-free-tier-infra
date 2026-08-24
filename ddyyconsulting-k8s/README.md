# ddyyconsulting-k8s

OpenTofu layer that installs Traefik (Gateway API), cert-manager, and ArgoCD onto the
existing OKE cluster from `../ddyyconsulting`, exposing ArgoCD at <https://argocd.ddyy.pro>.

The Kubernetes/Helm providers authenticate via the OCI exec-token plugin over the OCI
Bastion tunnel. The cluster CA is read from the cluster's kube-config via the `oci`
provider (`oci_containerengine_cluster_kube_config`) — the OKE module does not export it.

## Prerequisites

- **One-time, manual:** create the private repo `langburd/gitops` in GitHub.

## Prerequisites (every plan/apply)

1. Apply `../ddyyconsulting` first (provides cluster id + restricted LB NSG).
2. Open the OCI Bastion tunnel so `127.0.0.1:6443` reaches the private API endpoint
   (see `../ddyyconsulting` output `oke_bastion_connect`). The Kubernetes/Helm providers
   and all `kubernetes_manifest` resources require this at PLAN time.
3. Export the chunked-encoding workaround and the secrets.

## Configuration

Non-secret configuration (FQDN, DNS zone, ACME email, GitOps repo URL/path/branch,
namespaces, chart versions) is fixed in [`locals.tf`](./locals.tf) — edit there, no
`terraform.tfvars` needed. Only secrets are supplied at runtime, via `TF_VAR_*`
environment variables (never committed):

| Env var | Secret | Cloudflare scope |
| --- | --- | --- |
| `TF_VAR_cloudflare_api_token` | Cloudflare token for the TF provider (A record + WAF rule) | `Zone:DNS:Edit` + `Zone:Zone WAF:Edit` @ `ddyy.pro` |
| `TF_VAR_certmanager_cf_token` | Cloudflare token for cert-manager DNS-01 | `Zone:DNS:Edit` + `Zone:Zone:Read` @ `ddyy.pro` |
| `TF_VAR_argocd_admin_password_bcrypt` | Bcrypt hash of the ArgoCD admin password | — |
| `TF_VAR_argocd_client_cidrs` | JSON list of CIDRs allowed to reach `argocd.ddyy.pro` | — |

See [`docs/cloudflare-tokens.md`](../docs/cloudflare-tokens.md) for how to mint the two
Cloudflare tokens. Generate the bcrypt hash with:

```bash
htpasswd -nbBC 10 "" '<password>' | tr -d ':\n' | sed 's/$2y/$2a/'
```

Export everything before running `tofu`:

```bash
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
export TF_VAR_cloudflare_api_token=...        # Zone:DNS:Edit @ ddyy.pro
export TF_VAR_certmanager_cf_token=...         # Zone:DNS:Edit + Zone:Zone:Read @ ddyy.pro
export TF_VAR_argocd_admin_password_bcrypt='$2a$...'
export TF_VAR_argocd_client_cidrs='["203.0.113.4/32"]'
```

`argocd_admin_password_mtime` stays a variable (default `2026-06-27T00:00:00Z`); override
it only if you deliberately want to reset the admin password.

## Post-apply, one-time (deploy key)

After the first apply, add the generated public key as a read-only deploy key:

```bash
tofu output -raw gitops_deploy_public_key
# GitHub: langburd/gitops → Settings → Deploy keys → Add deploy key (read-only).
```

ArgoCD's repo connection stays "failed" until this is done.

## First apply (CRD ordering)

`kubernetes_manifest` performs a server-side dry-run at **plan time** — CRDs must exist in
the cluster before `tofu plan` runs. `depends_on` only controls apply ordering, not
plan-time CRD availability. On a clean cluster, install charts in three targeted steps
before running a full apply:

```bash
# Step 1 — namespaces + cert-manager (installs ClusterIssuer/Certificate CRDs)
tofu apply \
  -target=kubernetes_namespace.cert_manager \
  -target=kubernetes_namespace.argocd \
  -target=kubernetes_namespace.traefik \
  -target=helm_release.cert_manager

# Step 2 — Traefik (installs Gateway/HTTPRoute/GatewayClass CRDs)
tofu apply -target=helm_release.traefik

# Step 3 — ArgoCD (installs Application CRD)
tofu apply -target=helm_release.argocd

# Step 4 — all kubernetes_manifest resources + remainder (CRDs now present)
tofu apply
```

Subsequent applies on an already-provisioned cluster need no targeting.

### Stuck Helm release

If a targeted apply fails mid-install, Helm leaves the release in `pending-install`.
OpenTofu's next apply will error: `cannot re-use a name that is still in use`. Fix:

```bash
helm uninstall <release> -n <namespace>
```

Then retry the targeted apply.

## IP allowlist (per-FQDN)

Access to `argocd.ddyy.pro` is restricted to `var.argocd_client_cidrs`, enforced at two
independent layers. Both are scoped to that one hostname — every other name in `ddyy.pro`
is unaffected.

| Layer | Mechanism | Rejects with |
| --- | --- | --- |
| Cloudflare edge | `cloudflare_ruleset` custom rule, expression matches `http.host eq "argocd.ddyy.pro"` ([`waf.tf`](./waf.tf)) | Cloudflare `403` block page |
| Origin (Traefik) | `Middleware` `ipAllowList` + `ipStrategy.depth = 1`, attached to the ArgoCD `HTTPRoute` via an `ExtensionRef` filter ([`bootstrap.tf`](./bootstrap.tf)) | Traefik `403` |

The origin layer exists so that discovering the NLB's public IP is not enough to bypass
the edge rule. Gateway API has no core IP filter, hence the Traefik-specific
`Middleware`; `ExtensionRef` has no namespace field, so the `Middleware` must stay in the
same namespace as the `HTTPRoute` referencing it.

Separately, the origin only accepts Cloudflare, enforced by `worker_nsg` ingress rules in
the [`../ddyyconsulting`](../ddyyconsulting) layer that permit the NodePort range from
Cloudflare's ranges only. That one is cluster-wide, not per-hostname.

> Do **not** try to do this with `Service.loadBalancerSourceRanges`. The OCI CCM silently
> ignores it for NLBs — it creates no NSG on the load balancer and writes no security list
> rule, so it reads as a lockdown while enforcing nothing. Verify with
> `oci nlb network-load-balancer get --network-load-balancer-id <id> --query 'data."network-security-group-ids"'`;
> an empty list means nothing was applied.

### The chain that makes the client IP trustworthy

Every link is required; break one and the origin allowlist either fails open or fails
closed:

1. **A proxied DNS record** (`dns.tf`) means the TCP peer is always a Cloudflare edge IP,
   never the user. The real IP arrives only in `X-Forwarded-For`.
2. **`data.cloudflare_ip_ranges`** feeds Cloudflare's published ranges into the Traefik
   entrypoint's `forwardedHeaders.trustedIPs`. Traefik discards an inbound `XFF` from any
   other peer, so a direct-to-origin caller cannot forge an allowlisted IP.
3. **`ipStrategy.depth = 1`** reads the *rightmost* `XFF` entry — the address Cloudflare
   itself observed. Anything the client prepends lands to the left and is ignored.
4. **An OCI NLB with `externalTrafficPolicy: Local`.** The flexible LBaaS proxies TCP and
   rewrites the source address; with the default `Cluster` policy kube-proxy SNATs it
   again. Either one makes step 2 fail to match, and Traefik then throws the header away.
   NLB is also free, leaving the free-tier flexible LB allowance unused.
5. **Worker NSG rules that expect a preserved source IP.** `Local` sets
   `is-preserve-source = true` on the NLB backend sets, so packets reach the NodePort
   bearing a *Cloudflare* address rather than the LB's private IP in `10.0.3.0/24`. NSG
   rules scoped to the LB subnet silently stop matching the data path. It also allocates a
   `healthCheckNodePort` that the NLB probes instead of kube-proxy's port 10256 — with no
   rule for it, every backend goes CRITICAL and the NLB answers nothing. Both rules live
   in `worker_nsg` in the `../ddyyconsulting` layer and cover the whole NodePort range,
   because neither port number can be pinned without recreating the Service.

Consequence of `Local`: a node is a healthy NLB backend only while it runs a Traefik
pod. Nodes without one report CRITICAL **by design** — that is how `Local` signals "no
local endpoint here", not a fault.

Traefik therefore runs `replicas: 2`, one per worker node, so both backends are healthy
and a single pod or node loss is survivable. Two settings keep that true:

| Setting | Why |
| --- | --- |
| `topologySpreadConstraints`, `maxSkew: 1` on `kubernetes.io/hostname` | Forces one pod per node. `maxSkew` rather than required `podAntiAffinity`: the rollout is `maxSurge: 1 / maxUnavailable: 0`, so an update briefly wants 3 pods on 2 nodes — anti-affinity would leave the surge pod `Pending` and deadlock it, while a 2/1 split satisfies `maxSkew: 1`. `nodeTaintsPolicy: Honor` excludes a cordoned node so `kubectl drain` does not hang. |
| `podDisruptionBudget.minAvailable: 1` | An eviction taking both pods at once is a full outage, not a degraded one — every backend loses its local endpoint simultaneously. |

Two replicas are only safe because certificates come from cert-manager Secrets. Traefik's
own ACME resolver writes a file-based `acme.json` with a single-writer constraint and
would corrupt with more than one replica.

`replicas` is hardcoded to match `var.node_count` in `../ddyyconsulting` (2). Changing the
node count means changing both.

### Changing the allowlist

Editing `argocd_client_cidrs` alone needs a plain `tofu apply` — the `Middleware` and the
WAF rule both update in place.

Editing the `HTTPRoute` itself needs `-replace`: `spec.rules` sits in its
`computed_fields`, so the provider ignores config changes beneath it and produces no
diff at all.

```bash
tofu apply -replace=kubernetes_manifest.argocd_httproute
```

Cloudflare's edge ranges change occasionally. When they do, re-apply both layers — the
`ddyyconsulting` layer refreshes the `worker_nsg` NodePort rules and this one refreshes
`trustedIPs`. A stale list shows up as Cloudflare error 522.

## Verify

```bash
kubectl get gatewayclass traefik
kubectl -n traefik get gateway
kubectl -n traefik get secret argocd-tls
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://argocd.ddyy.pro/healthz   # 200 0
kubectl -n argocd get application root

# Proxying is live (expect a Cloudflare edge IP, not the NLB's, plus a cf-ray header).
dig +short argocd.ddyy.pro
curl -sSI https://argocd.ddyy.pro/ | grep -i '^cf-ray\|^server'

# IP allowlist: 200 from an allowed CIDR, 403 from anywhere else (e.g. phone hotspot).
kubectl -n argocd get middleware argocd-ipallow
kubectl -n argocd get httproute argocd -o jsonpath='{.spec.rules[0].filters}'
curl -sS -o /dev/null -w '%{http_code}\n' https://argocd.ddyy.pro/

# Which client IP the origin actually saw (should be your real IP, not a Cloudflare one).
kubectl -n traefik logs deploy/traefik | tail -5
```

The `argocd` CLI speaks gRPC, which needs the gRPC-Web fallback through Cloudflare:

```bash
argocd login argocd.ddyy.pro --grpc-web
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.4 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.0 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | ~> 8.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.23.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.1 |
| <a name="provider_oci"></a> [oci](#provider\_oci) | 8.28.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.argocd](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_ruleset.zone_firewall_custom](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/ruleset) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.traefik](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.app_of_apps](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_certificate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_http_redirect](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_httproute](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_ipallow](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.letsencrypt_issuer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.argocd](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.traefik](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.cloudflare_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.gitops_repo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [tls_private_key.deploy](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [cloudflare_ip_ranges.cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/ip_ranges) | data source |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |
| [kubernetes_service.traefik](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service) | data source |
| [oci_containerengine_cluster_kube_config.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/containerengine_cluster_kube_config) | data source |
| [terraform_remote_state.infra](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_argocd_admin_password_bcrypt"></a> [argocd\_admin\_password\_bcrypt](#input\_argocd\_admin\_password\_bcrypt) | Bcrypt hash of the ArgoCD admin password. | `string` | n/a | yes |
| <a name="input_argocd_admin_password_mtime"></a> [argocd\_admin\_password\_mtime](#input\_argocd\_admin\_password\_mtime) | Fixed RFC3339 timestamp for argocdServerAdminPasswordMtime. Set ONCE (e.g. 2026-06-27T00:00:00Z). Changing it resets the admin password; do not use a dynamic value. | `string` | `"2026-06-27T00:00:00Z"` | no |
| <a name="input_argocd_client_cidrs"></a> [argocd\_client\_cidrs](#input\_argocd\_client\_cidrs) | CIDRs permitted to reach argocd.ddyy.pro. Enforced per-FQDN at two layers: a Cloudflare WAF rule scoped to the hostname, and a Traefik ipAllowList Middleware on the ArgoCD HTTPRoute. Other hostnames are unaffected. | `list(string)` | n/a | yes |
| <a name="input_certmanager_cf_token"></a> [certmanager\_cf\_token](#input\_certmanager\_cf\_token) | Cloudflare API token for cert-manager DNS-01 (Zone:DNS:Edit + Zone:Zone:Read on the zone). | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for the TF provider (Zone:DNS:Edit on the zone). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_argocd_admin_hint"></a> [argocd\_admin\_hint](#output\_argocd\_admin\_hint) | How to log in to ArgoCD. |
| <a name="output_argocd_url"></a> [argocd\_url](#output\_argocd\_url) | ArgoCD UI URL. |
| <a name="output_gitops_deploy_public_key"></a> [gitops\_deploy\_public\_key](#output\_gitops\_deploy\_public\_key) | Public half of the TF-generated deploy key. Add this to langburd/gitops → Settings → Deploy keys (read-only). |
| <a name="output_traefik_lb_ip"></a> [traefik\_lb\_ip](#output\_traefik\_lb\_ip) | Public IP of the OCI Load Balancer fronting Traefik. |
<!-- END_TF_DOCS -->
