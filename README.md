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
