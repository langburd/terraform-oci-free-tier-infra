locals {
  profile_name = "ddyyconsulting"
  region       = "il-jerusalem-1"
  default_tags = {
    "Environment" = "Dev"
    "GitRepo"     = "https://github.com/langburd/terraform-oci-free-tier-infra/tree/master/ddyyconsulting"
    "ManagedBy"   = "OpenTofu"
  }

  # SSH public key with fallback to default location.
  ssh_public_key = var.ssh_public_key != null ? var.ssh_public_key : file(pathexpand("~/.ssh/langburd.pub"))

  # CIDR blocks — single source of truth for all NSG rules and subnet definitions.
  cidr_vcn        = "10.0.0.0/16"
  cidr_api_subnet = "10.0.1.0/24"
  cidr_worker     = "10.0.2.0/24"
  cidr_lb         = "10.0.3.0/24"
  cidr_db         = "10.0.4.0/24"
  cidr_all        = "0.0.0.0/0"

  # DNS labels — the Vaultwarden DB FQDN (and its certificate SAN) is built from these.
  dns_label_vcn           = "k8svcn"
  dns_label_db_subnet     = "db"
  vaultwarden_db_hostname = "vaultwarden-mysql"

  # Worker node shape.
  node_shape = "VM.Standard.A1.Flex"

  # Kubernetes version — upgrade one minor at a time (OCI constraint).
  kubernetes_version = "v1.36.1"
}
