terraform {
  required_version = ">= 1.8.4"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

provider "oci" {
  config_file_profile = local.profile_name
}
