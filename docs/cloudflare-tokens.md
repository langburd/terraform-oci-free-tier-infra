# Creating the Cloudflare API tokens

The `ddyyconsulting-k8s` layer needs **two** scoped Cloudflare API tokens, both limited to
the `ddyy.pro` zone. Keeping them separate follows least-privilege: the Terraform provider
token can only edit DNS records, while the cert-manager token additionally reads zone
metadata for the DNS-01 challenge and lives inside the cluster as a Kubernetes Secret.

| Token | Consumed by | Stored where | Permissions |
| --- | --- | --- | --- |
| **TF provider token** | `provider "cloudflare"` — creates the `argocd` A record **and** the WAF custom rule that gates access to it | `TF_VAR_cloudflare_api_token` env var (never in state as plaintext beyond normal TF handling) | `Zone → DNS → Edit` **and** `Zone → Zone WAF → Edit` |
| **cert-manager token** | cert-manager DNS-01 solver (Let's Encrypt) | `TF_VAR_certmanager_cf_token` → Kubernetes Secret `cloudflare-api-token` in the `cert-manager` namespace | `Zone → DNS → Edit` **and** `Zone → Zone → Read` |

Both are scoped to **`ddyy.pro`** only. Do not grant account-wide or all-zones access.

> `Zone WAF → Edit` was added when `argocd.ddyy.pro` became a proxied record. The
> `cloudflare_ruleset` resource in `ddyyconsulting-k8s/waf.tf` manages the zone's
> `http_request_firewall_custom` phase, which a DNS-only token cannot touch. If you are
> rotating an older token, add this permission or `tofu apply` will fail on that resource.

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
   - TF provider token — add two rows:
     - `Zone` · `DNS` · `Edit`
     - `Zone` · `Zone WAF` · `Edit`
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

## Zone settings the proxied record depends on

Not TF-managed — zone-level SSL settings affect every proxied hostname in `ddyy.pro`, so
they are left to the dashboard rather than given a blast radius in this repo. Check them
once, under **SSL/TLS** for the `ddyy.pro` zone:

| Setting | Required value | Why |
| --- | --- | --- |
| SSL/TLS encryption mode | **Full (strict)** | Cloudflare re-originates over HTTPS to Traefik, which serves a real Let's Encrypt cert. `Flexible` would make Cloudflare talk plain HTTP to port 80 and break the HTTPS→HTTPS path; `Full` (non-strict) would skip origin cert validation. |
| Always Use HTTPS | **On** | Redirects HTTP at the edge, so the `argocd-redirect` HTTPRoute becomes a fallback rather than the primary path. |

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
   `tofu apply` — the `kubernetes_secret_v1.cloudflare_token` resource updates the in-cluster
   Secret. cert-manager reloads it automatically.
4. Delete the old token in the Cloudflare dashboard once the new one is confirmed working.

## Troubleshooting

- **Certificate stuck `Ready=False`, challenge failing:** most often the cert-manager
  token is missing `Zone:Zone:Read`. Verify the scope with the `verify` call above.
  Debug with `kubectl -n traefik describe certificate argocd-tls` and
  `kubectl get challenges -A`.
- **`tofu apply` fails creating the A record with `Authentication error`:** the TF token
  is invalid, expired, or scoped to the wrong zone.
- **`cloudflare_ruleset.zone_firewall_custom` fails with a 403 / `Unauthorized`:** the TF
  token is missing `Zone:Zone WAF:Edit`. Re-mint it per the table above.
- **`argocd.ddyy.pro` returns Cloudflare error 526 (invalid SSL certificate):** the zone's
  SSL/TLS mode is `Full (strict)` but the origin cert is missing or expired. Check
  `kubectl -n traefik describe certificate argocd-tls`.
- **Cloudflare error 522 (connection timed out):** the NLB has no healthy backend, or the
  data path is being dropped by the worker NSG. Check health first:

  ```bash
  oci nlb backend-set-health get --network-load-balancer-id <nlb-ocid> \
    --backend-set-name TCP-443 --profile ddyyconsulting
  ```

  `CRITICAL` on *every* backend means the NLB's `healthCheckNodePort` probe is blocked —
  `worker_nsg` must permit the NodePort range from `10.0.3.0/24`. Expect `OK` on both
  backends: Traefik runs one replica per node, and under `externalTrafficPolicy: Local` a
  node is only healthy while it hosts a pod. A single `CRITICAL` backend means that node's
  Traefik pod is missing — check `kubectl -n traefik get pods -o wide` for a `Pending` pod
  before blaming the network. If health is fine but
  requests still time out, `worker_nsg` is missing the Cloudflare ranges for the NodePort
  range (the NLB preserves the client source IP, so LB-subnet-scoped rules do not match),
  or Cloudflare published new ranges — re-run `tofu apply` in `ddyyconsulting` to refresh.
- **Everything returns 403 from Traefik, not Cloudflare:** the `ipAllowList` Middleware
  read the wrong X-Forwarded-For position. Inspect the Traefik access log for the client
  IP it saw (`kubectl -n traefik logs deploy/traefik | tail -20`) and adjust
  `ipStrategy.depth` in `ddyyconsulting-k8s/bootstrap.tf`.
