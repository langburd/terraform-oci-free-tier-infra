terraform {
  required_version = ">= 1.8.4"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "oci" {
  config_file_profile = local.profile_name
}
