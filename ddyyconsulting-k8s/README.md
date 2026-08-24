# ddyyconsulting-k8s

OpenTofu layer that installs Traefik (Gateway API), cert-manager, and ArgoCD onto the
existing OKE cluster from `../ddyyconsulting`, exposing ArgoCD at https://argocd.ddyy.pro.

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
| `TF_VAR_cloudflare_api_token` | Cloudflare token for the TF provider (creates the A record) | `Zone:DNS:Edit` @ `ddyy.pro` |
| `TF_VAR_certmanager_cf_token` | Cloudflare token for cert-manager DNS-01 | `Zone:DNS:Edit` + `Zone:Zone:Read` @ `ddyy.pro` |
| `TF_VAR_argocd_admin_password_bcrypt` | Bcrypt hash of the ArgoCD admin password | — |

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

## Verify

```bash
kubectl get gatewayclass traefik
kubectl -n traefik get gateway
kubectl -n traefik get secret argocd-tls
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://argocd.ddyy.pro/healthz   # 200 0
kubectl -n argocd get application root
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.4 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | ~> 8.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.21.1 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_oci"></a> [oci](#provider\_oci) | 8.20.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.argocd](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.traefik](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.argocd_certificate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_http_redirect](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.argocd_httproute](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.letsencrypt_issuer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.root_app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.argocd](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.traefik](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.cloudflare_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.gitops_repo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [tls_private_key.deploy](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |
| [kubernetes_service.traefik](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service) | data source |
| [oci_containerengine_cluster_kube_config.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/containerengine_cluster_kube_config) | data source |
| [terraform_remote_state.infra](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_argocd_admin_password_bcrypt"></a> [argocd\_admin\_password\_bcrypt](#input\_argocd\_admin\_password\_bcrypt) | Bcrypt hash of the ArgoCD admin password. | `string` | n/a | yes |
| <a name="input_argocd_admin_password_mtime"></a> [argocd\_admin\_password\_mtime](#input\_argocd\_admin\_password\_mtime) | Fixed RFC3339 timestamp for argocdServerAdminPasswordMtime. Set ONCE (e.g. 2026-06-27T00:00:00Z). Changing it resets the admin password; do not use a dynamic value. | `string` | `"2026-06-27T00:00:00Z"` | no |
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
