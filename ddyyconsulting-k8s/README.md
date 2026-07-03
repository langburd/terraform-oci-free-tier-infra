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
3. Export the chunked-encoding workaround and secrets:
   ```bash
   export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
   export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
   export TF_VAR_cloudflare_api_token=...   # Zone:DNS:Edit @ ddyy.pro
   export TF_VAR_certmanager_cf_token=...   # Zone:DNS:Edit + Zone:Zone:Read @ ddyy.pro
   export TF_VAR_argocd_admin_password_bcrypt='$2a$...'
   ```

## Post-apply, one-time (deploy key)

After the first apply, add the generated public key as a read-only deploy key:
```bash
tofu output -raw gitops_deploy_public_key
# GitHub: langburd/gitops → Settings → Deploy keys → Add deploy key (read-only).
```
ArgoCD's repo connection stays "failed" until this is done.

## First apply (CRD ordering)

`kubernetes_manifest` resources need their CRDs present at plan time. On a clean cluster,
apply the charts first, then the manifests:

```bash
tofu apply -target=helm_release.cert_manager
tofu apply -target=helm_release.traefik -target=helm_release.argocd
tofu apply
```

Subsequent applies need no targeting.

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
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact email for Let's Encrypt ACME registration. | `string` | `"alerts@ddyy.pro"` | no |
| <a name="input_argocd_admin_password_bcrypt"></a> [argocd\_admin\_password\_bcrypt](#input\_argocd\_admin\_password\_bcrypt) | Bcrypt hash of the ArgoCD admin password (htpasswd -nbBC 10 "" <pw> \| tr -d ':\n' \| sed 's/$2y/$2a/'). | `string` | n/a | yes |
| <a name="input_argocd_admin_password_mtime"></a> [argocd\_admin\_password\_mtime](#input\_argocd\_admin\_password\_mtime) | Fixed RFC3339 timestamp for argocdServerAdminPasswordMtime. Set ONCE (e.g. 2026-06-27T00:00:00Z). Changing it resets the admin password; do not use a dynamic value. | `string` | `"2026-06-27T00:00:00Z"` | no |
| <a name="input_argocd_fqdn"></a> [argocd\_fqdn](#input\_argocd\_fqdn) | FQDN for the ArgoCD UI. | `string` | `"argocd.ddyy.pro"` | no |
| <a name="input_certmanager_cf_token"></a> [certmanager\_cf\_token](#input\_certmanager\_cf\_token) | Cloudflare API token for cert-manager DNS-01 (Zone:DNS:Edit + Zone:Zone:Read on the zone). | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for the TF provider (Zone:DNS:Edit on the zone). | `string` | n/a | yes |
| <a name="input_cloudflare_zone_name"></a> [cloudflare\_zone\_name](#input\_cloudflare\_zone\_name) | Cloudflare DNS zone hosting the FQDN. | `string` | `"ddyy.pro"` | no |
| <a name="input_gitops_repo_branch"></a> [gitops\_repo\_branch](#input\_gitops\_repo\_branch) | Branch the ArgoCD root app tracks. | `string` | `"master"` | no |
| <a name="input_gitops_repo_path"></a> [gitops\_repo\_path](#input\_gitops\_repo\_path) | Path inside the GitOps repo for the app-of-apps root. | `string` | `"apps"` | no |
| <a name="input_gitops_repo_url"></a> [gitops\_repo\_url](#input\_gitops\_repo\_url) | SSH (scp-style) URL of the private GitOps repo. MUST be git@host:org/repo.git, not https:// — ArgoCD matches the SSH key only against scp-style URLs. | `string` | `"git@github.com:langburd/gitops.git"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_argocd_admin_hint"></a> [argocd\_admin\_hint](#output\_argocd\_admin\_hint) | How to log in to ArgoCD. |
| <a name="output_argocd_url"></a> [argocd\_url](#output\_argocd\_url) | ArgoCD UI URL. |
| <a name="output_gitops_deploy_public_key"></a> [gitops\_deploy\_public\_key](#output\_gitops\_deploy\_public\_key) | Public half of the TF-generated deploy key. Add this to langburd/gitops → Settings → Deploy keys (read-only). |
| <a name="output_traefik_lb_ip"></a> [traefik\_lb\_ip](#output\_traefik\_lb\_ip) | Public IP of the OCI Load Balancer fronting Traefik. |
<!-- END_TF_DOCS -->
