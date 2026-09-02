terraform {
  required_version = ">= 1.8.4"

  backend "s3" {
    bucket = "ddyyconsulting-terraform-states"
    endpoints = {
      s3 = "https://axbasucxrqax.compat.objectstorage.il-jerusalem-1.oraclecloud.com"
    }
    key                         = "terraform-oci-free-tier-infra/k8s.tfstate"
    profile                     = "ddyyconsulting"
    region                      = "il-jerusalem-1"
    shared_credentials_files    = ["~/.oci/config"]
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = false
  }

  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.0" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    oci        = { source = "oracle/oci", version = "~> 9.0" }
  }
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket                      = "ddyyconsulting-terraform-states"
    key                         = "terraform-oci-free-tier-infra/terraform.tfstate"
    region                      = "il-jerusalem-1"
    profile                     = "ddyyconsulting"
    endpoints                   = { s3 = "https://axbasucxrqax.compat.objectstorage.il-jerusalem-1.oraclecloud.com" }
    shared_credentials_files    = ["~/.oci/config"]
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

# OCI provider — used only to read the cluster kube-config (CA cert) for the
# Kubernetes/Helm providers. The OKE module does not export the CA directly.
provider "oci" {
  config_file_profile = "ddyyconsulting"
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = base64decode(local.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "oci"
    args = [
      "ce", "cluster", "generate-token",
      "--cluster-id", local.cluster_id,
      "--region", "il-jerusalem-1",
      "--profile", "ddyyconsulting",
    ]
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.k8s_host
    cluster_ca_certificate = base64decode(local.cluster_ca)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "oci"
      args = [
        "ce", "cluster", "generate-token",
        "--cluster-id", local.cluster_id,
        "--region", "il-jerusalem-1",
        "--profile", "ddyyconsulting",
      ]
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "tls" {}
