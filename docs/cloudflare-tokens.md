# Creating the Cloudflare API tokens

The `ddyyconsulting-k8s` layer needs **two** scoped Cloudflare API tokens, both limited to
the `ddyy.pro` zone. Keeping them separate follows least-privilege: the Terraform provider
token can only edit DNS records, while the cert-manager token additionally reads zone
metadata for the DNS-01 challenge and lives inside the cluster as a Kubernetes Secret.

| Token | Consumed by | Stored where | Permissions |
| --- | --- | --- | --- |
| **TF provider token** | `provider "cloudflare"` — creates the `argocd` A record | `TF_VAR_cloudflare_api_token` env var (never in state as plaintext beyond normal TF handling) | `Zone → DNS → Edit` |
| **cert-manager token** | cert-manager DNS-01 solver (Let's Encrypt) | `TF_VAR_certmanager_cf_token` → Kubernetes Secret `cloudflare-api-token` in the `cert-manager` namespace | `Zone → DNS → Edit` **and** `Zone → Zone → Read` |

Both are scoped to **`ddyy.pro`** only. Do not grant account-wide or all-zones access.

## Prerequisites

- Access to the Cloudflare account that hosts the `ddyy.pro` zone.
- Permission to create API tokens (Account → My Profile → API Tokens, or an admin role).

## Procedure

Do this twice — once per token. Use the **Create Custom Token** flow (the "Edit zone DNS"
template covers the TF token but does not add `Zone:Read`, which cert-manager needs, so a
custom token is clearer for both).

1. Log in to the Cloudflare dashboard.
2. Go to **My Profile → API Tokens** (`https://dash.cloudflare.com/profile/api-tokens`).
3. Click **Create Token → Create Custom Token → Get started**.
4. **Token name:** use something identifying, e.g.
   - `ddyy-oke-tf-dns` (TF provider token)
   - `ddyy-oke-certmanager-dns01` (cert-manager token)
5. **Permissions:**
   - TF provider token — add one row:
     - `Zone` · `DNS` · `Edit`
   - cert-manager token — add two rows:
     - `Zone` · `DNS` · `Edit`
     - `Zone` · `Zone` · `Read`
6. **Zone Resources:** set to
   `Include` · `Specific zone` · `ddyy.pro`.
7. (Optional but recommended) **Client IP Address Filtering:** restrict to the operator's
   egress IP. Leave blank if you apply from varying networks.
8. (Optional) **TTL:** leave as default (no expiry) or set an expiry and rotate.
9. Click **Continue to summary**, review, then **Create Token**.
10. **Copy the token value now** — Cloudflare shows it once. Store it in your password
    manager.

## Using the tokens

Export them before running `tofu` in `ddyyconsulting-k8s/`:

```bash
export TF_VAR_cloudflare_api_token=<tf-provider-token>       # ddyy-oke-tf-dns
export TF_VAR_certmanager_cf_token=<cert-manager-token>       # ddyy-oke-certmanager-dns01
```

## Verifying a token

Confirm a token is valid and see its scope:

```bash
curl -sS https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer <token>" | jq
```

Expected: `"status": "active"` in the result.

## Rotation

Tokens can be rolled without downtime:

1. Create a replacement token with the same scope (steps above).
2. For the **TF token:** update `TF_VAR_cloudflare_api_token` and re-run `tofu apply` (or
   just the next apply picks it up — the token is not persisted as a managed resource).
3. For the **cert-manager token:** update `TF_VAR_certmanager_cf_token` and
   `tofu apply` — the `kubernetes_secret.cloudflare_token` resource updates the in-cluster
   Secret. cert-manager reloads it automatically.
4. Delete the old token in the Cloudflare dashboard once the new one is confirmed working.

## Troubleshooting

- **Certificate stuck `Ready=False`, challenge failing:** most often the cert-manager
  token is missing `Zone:Zone:Read`. Verify the scope with the `verify` call above.
  Debug with `kubectl -n traefik describe certificate argocd-tls` and
  `kubectl get challenges -A`.
- **`tofu apply` fails creating the A record with `Authentication error`:** the TF token
  is invalid, expired, or scoped to the wrong zone.
