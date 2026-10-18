# ddyyconsulting-k8s

OpenTofu layer that bootstraps ArgoCD onto the existing OKE cluster from
`../ddyyconsulting` and hands everything else (Traefik, cert-manager, External Secrets,
metrics-server, ArgoCD itself) to GitOps via [`langburd/gitops`](https://github.com/langburd/gitops).
ArgoCD is exposed at <https://argocd.ddyy.pro>.

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
| `TF_VAR_argocd_client_cidrs` | JSON list of CIDRs allowed to reach `argocd.ddyy.pro` | — |

The cert-manager Cloudflare token and the ArgoCD admin password hash are no longer inputs
here: they live in OCI Vault, managed by [`../ddyyconsulting`](../ddyyconsulting/README.md#vault-secrets)
and synced into the cluster by External Secrets. See
[`docs/cloudflare-tokens.md`](../docs/cloudflare-tokens.md) for how to mint the Cloudflare tokens.

```bash
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
export TF_VAR_cloudflare_api_token=...        # Zone:DNS:Edit + Zone:Zone WAF:Edit @ ddyy.pro
export TF_VAR_argocd_client_cidrs='["203.0.113.4/32"]'
```

## Post-apply, one-time (deploy key)

After the first apply, add the generated public key as a read-only deploy key:

```bash
tofu output -raw gitops_deploy_public_key
# GitHub: langburd/gitops → Settings → Deploy keys → Add deploy key (read-only).
```

ArgoCD's repo connection stays "failed" until this is done.

## Bootstrap

This layer does the minimum needed for ArgoCD to take over; everything after that is
driven by `langburd/gitops`.

1. `helm_release.argocd` installs ArgoCD once (`lifecycle { ignore_changes = all }`).
   From then on ArgoCD is self-managed by the gitops `argocd` addon. For break-glass
   re-installs use `tofu apply -replace=helm_release.argocd`; the admin password is
   restored by the ESO ExternalSecret, not by chart values.
2. A TF-generated deploy key and the `gitops-repo` Secret give ArgoCD read access to
   `langburd/gitops` (see the deploy-key step above).
3. The cluster Secret `ddyy-oke` carries the GitOps Bridge labels (`enable_*`) and
   annotations (FQDN, reserved IP, LB NSG, Vault id, ...) that drive the addon
   ApplicationSets.
4. The root Application `app-of-apps` tracks `langburd/gitops` path `bootstrap/`.
5. DNS: the proxied `argocd.ddyy.pro` record points at the reserved IP from
   `../ddyyconsulting`.

On a clean cluster a plain `tofu apply` is enough, except that `app-of-apps` is a
`kubernetes_manifest` (server-side dry-run at plan time needs the `Application` CRD), so
install ArgoCD first:

```bash
tofu apply -target=kubernetes_namespace_v1.argocd -target=helm_release.argocd
tofu apply
```

### Addon autosync

The cluster Secret annotation `addons_autosync` (in
`kubernetes-secret-argocd-cluster.tf`) controls whether generated addon Applications
sync automatically. It is `"true"`. Set it to `"false"` and apply to review
`argocd app diff <app>` before syncing manually.

### Gotchas

- The OCI CCM cannot attach a reserved IP to an existing NLB. If the traefik Service was
  created before the reserved IP was wired in, delete the Service once
  (`kubectl -n traefik delete svc traefik`) and let ArgoCD recreate it.
- New Vault endpoints need a few minutes of DNS propagation; ExternalSecrets may report
  errors until then and recover on their own.

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

Ownership is split: this layer owns the Cloudflare rule, the DNS record and the CIDR list
(`argocd_client_cidrs` TF var → cluster Secret annotation `argocd_client_cidrs`). The
`ipAllowList` Middleware, the HTTPRoutes and the Certificate live in `langburd/gitops`
`addons/argocd/manifests`, and the Traefik NLB settings in `addons/traefik`; ArgoCD renders
the allowlist from the annotation.

| Layer | Mechanism | Rejects with |
| --- | --- | --- |
| Cloudflare edge | `cloudflare_ruleset` custom rule, expression matches `http.host eq "argocd.ddyy.pro"` ([`cloudflare-ruleset-zone-firewall-custom.tf`](./cloudflare-ruleset-zone-firewall-custom.tf)) | Cloudflare `403` block page |
| Origin (Traefik) | `Middleware` `ipAllowList` + `ipStrategy.depth = 1`, attached to the ArgoCD `HTTPRoute` via an `ExtensionRef` filter (`middleware-ipallow.yaml` in `langburd/gitops` `addons/argocd/manifests/templates/`) | Traefik `403` |

The origin layer exists so that discovering the NLB's public IP is not enough to bypass
the edge rule. Gateway API has no core IP filter, hence the Traefik-specific
`Middleware`; `ExtensionRef` has no namespace field, so the `Middleware` must stay in the
same namespace as the `HTTPRoute` referencing it.

Separately, the origin only accepts Cloudflare, enforced by two NSGs in the
[`../ddyyconsulting`](../ddyyconsulting) layer: `lb_nsg` (80/443 into the NLB) and
`worker_nsg` (the NodePort range into the nodes), both scoped to Cloudflare's ranges.
Those are cluster-wide, not per-hostname.

> Do **not** try to do this with `Service.loadBalancerSourceRanges`. The OCI CCM silently
> ignores it for NLBs — it creates no NSG on the load balancer and writes no security list
> rule, so it reads as a lockdown while enforcing nothing. `lb_nsg` is instead attached
> explicitly through the
> `oci-network-load-balancer.oraclecloud.com/network-security-group-ids` annotation in the
> Traefik values; the CCM does not manage security rules for NLBs the way it does for
> LBaaS, so without that annotation nothing permits edge traffic into the NLB. Verify with
> `oci nlb network-load-balancer get --network-load-balancer-id <id> --query 'data."network-security-group-ids"'`;
> an empty list means the annotation did not take.

### The chain that makes the client IP trustworthy

Every link is required; break one and the origin allowlist either fails open or fails
closed:

1. **A proxied DNS record** (`cloudflare-dns-record-argocd.tf`) means the TCP peer is always a Cloudflare edge IP,
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

Editing `argocd_client_cidrs` and running `tofu apply` updates the WAF rule and the cluster
Secret annotation in place; ArgoCD then re-renders the `Middleware` from the annotation.
Changes to the Middleware, HTTPRoutes or Certificate themselves are made in
`langburd/gitops` `addons/argocd/manifests`, not here.

Cloudflare's edge ranges change occasionally. When they do, re-apply both layers — the
`ddyyconsulting` layer refreshes the `worker_nsg` NodePort rules and this one refreshes the
`trusted_proxy_cidrs` annotation used for Traefik's `trustedIPs`. A stale list shows up as
Cloudflare error 522.

## Verify

```bash
# Secrets pipeline: Vault -> ESO
kubectl get clustersecretstore oci-vault                       # READY True
kubectl get externalsecret -A                                  # STATUS SecretSynced

# Ingress IP matches the reserved IP from ../ddyyconsulting
kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
tofu -chdir=../ddyyconsulting output -raw ingress_reserved_ip

# ArgoCD and all addons healthy
argocd app list                                                # all Synced / Healthy
kubectl -n argocd get application app-of-apps

# Proxying is live (expect a Cloudflare edge IP, not the NLB's, plus a cf-ray header).
dig +short argocd.ddyy.pro
curl -sSI https://argocd.ddyy.pro/ | grep -i '^cf-ray\|^server'

# IP allowlist: 200 from an allowed CIDR, 403 from anywhere else (e.g. phone hotspot).
curl -sS -o /dev/null -w '%{http_code}\n' https://argocd.ddyy.pro/
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
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | ~> 9.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 3.0 |
| <a name="provider_oci"></a> [oci](#provider\_oci) | ~> 9.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vaultwarden_offsite_secrets"></a> [vaultwarden\_offsite\_secrets](#module\_vaultwarden\_offsite\_secrets) | git@github.com:langburd/terraform-oci-free-tier-modules.git | oci/vault_secrets/v1.0.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.argocd](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_r2_bucket.vaultwarden_offsite](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/r2_bucket) | resource |
| [cloudflare_r2_bucket_lifecycle.vaultwarden_offsite](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/r2_bucket_lifecycle) | resource |
| [cloudflare_r2_bucket_lock.vaultwarden_offsite](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/r2_bucket_lock) | resource |
| [cloudflare_ruleset.zone_firewall_custom](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/ruleset) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.app_of_apps](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.argocd](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.argocd_cluster_ddyy_oke](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.gitops_repo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [tls_private_key.deploy](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [cloudflare_ip_ranges.cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/ip_ranges) | data source |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |
| [oci_containerengine_cluster_kube_config.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/containerengine_cluster_kube_config) | data source |
| [terraform_remote_state.infra](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_argocd_client_cidrs"></a> [argocd\_client\_cidrs](#input\_argocd\_client\_cidrs) | CIDRs permitted to reach argocd.ddyy.pro. Enforced per-FQDN at two layers: a Cloudflare WAF rule scoped to the hostname, and a Traefik ipAllowList Middleware on the ArgoCD HTTPRoute. Other hostnames are unaffected. | `list(string)` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for the TF provider (Zone:DNS:Edit on the zone). | `string` | n/a | yes |
| <a name="input_offsite_backup_age_recipient"></a> [offsite\_backup\_age\_recipient](#input\_offsite\_backup\_age\_recipient) | age public key (age1...) the Vaultwarden off-site backup is encrypted to. The private key stays offline, never in the cluster or OCI (langburd/gitops docs/vaultwarden.md). | `string` | n/a | yes |
| <a name="input_vaultwarden_r2_access_key_id"></a> [vaultwarden\_r2\_access\_key\_id](#input\_vaultwarden\_r2\_access\_key\_id) | Access key ID of the R2 API token scoped to the ddyy-vaultwarden-offsite bucket (Object Read & Write). Null until the token is created after the bucket. | `string` | `null` | no |
| <a name="input_vaultwarden_r2_secret_access_key"></a> [vaultwarden\_r2\_secret\_access\_key](#input\_vaultwarden\_r2\_secret\_access\_key) | Secret access key of the R2 API token scoped to the ddyy-vaultwarden-offsite bucket. Null until the token is created after the bucket. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_argocd_admin_hint"></a> [argocd\_admin\_hint](#output\_argocd\_admin\_hint) | How to log in to ArgoCD. |
| <a name="output_argocd_url"></a> [argocd\_url](#output\_argocd\_url) | ArgoCD UI URL. |
| <a name="output_gitops_deploy_public_key"></a> [gitops\_deploy\_public\_key](#output\_gitops\_deploy\_public\_key) | Public half of the TF-generated deploy key. Add this to langburd/gitops → Settings → Deploy keys (read-only). |
| <a name="output_ingress_reserved_ip"></a> [ingress\_reserved\_ip](#output\_ingress\_reserved\_ip) | Reserved public IP attached to the Traefik NLB. |
<!-- END_TF_DOCS -->
