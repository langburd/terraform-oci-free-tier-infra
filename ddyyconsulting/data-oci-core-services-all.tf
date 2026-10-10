# --- OKE cluster supporting data sources and locals ---

data "oci_core_services" "all" {}

locals {
  # Region-agnostic Oracle Services Network CIDR label, used by the Service Gateway routes.
  oci_services_candidates = [for s in data.oci_core_services.all.services :
    s.cidr_block if length(regexall("All .* Services In Oracle Services Network", s.name)) > 0
  ]
  oci_services_cidr = local.oci_services_candidates[0]
}

# Fail early with a clear message if the Oracle Services Network CIDR label can
# not be resolved (e.g. the service name format changed) before indexing it.
check "oci_services_cidr_resolved" {
  assert {
    condition     = length(local.oci_services_candidates) > 0
    error_message = "Could not resolve the 'All Services In Oracle Services Network' CIDR from oci_core_services."
  }
}
