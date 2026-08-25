# terraform-oci-free-tier-infra

The repository contains the `live` OCI environments that use the [langburd/terraform-oci-free-tier-modules](https://github.com/langburd/terraform-oci-free-tier-modules) repository as a source.

## Usage

Each environment (`ddyyconsulting/`, `langburd/`) is an independent OpenTofu root with its own remote state in an OCI Object Storage S3-compatible backend.

### Required environment variables

The AWS SDK behind the S3 backend forces `aws-chunked` encoding for default data-integrity checksums, which OCI Object Storage rejects with `501 NotImplemented: AWS chunked encoding not supported` on state upload (`skip_s3_checksum = true` in the backend is not enough). Export these before running `tofu` in any environment:

```bash
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

### Workflow

```bash
cd ddyyconsulting   # or langburd
tofu init           # required before first apply or after provider/module changes
tofu validate
tofu apply
```

Authentication uses profile-based config from `~/.oci/config`.

### Accessing the OKE cluster

The `ddyyconsulting/` environment runs a private OKE cluster reachable only through an OCI Bastion. See [`ddyyconsulting/README.md`](ddyyconsulting/README.md) for the bastion tunnel workflow and the `oke-connect` helper.

### `ddyyconsulting-k8s/` — first apply (multi-step)

The k8s layer uses `kubernetes_manifest` which dry-runs against the live API at **plan
time** — CRDs must already exist in the cluster. On a clean cluster, install in four steps:

```bash
cd ddyyconsulting-k8s

# Step 1 — namespaces + cert-manager (ClusterIssuer/Certificate CRDs)
tofu apply \
  -target=kubernetes_namespace_v1.cert_manager \
  -target=kubernetes_namespace_v1.argocd \
  -target=kubernetes_namespace_v1.traefik \
  -target=helm_release.cert_manager

# Step 2 — Traefik (Gateway/HTTPRoute/GatewayClass CRDs)
tofu apply -target=helm_release.traefik

# Step 3 — ArgoCD (Application CRD)
tofu apply -target=helm_release.argocd

# Step 4 — all remaining resources
tofu apply
```

Subsequent applies need no targeting. See [`ddyyconsulting-k8s/README.md`](ddyyconsulting-k8s/README.md) for prerequisites, secrets, and post-apply steps.
