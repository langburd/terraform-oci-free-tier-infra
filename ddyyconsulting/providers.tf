terraform {
  required_version = ">= 1.6.1"

  backend "s3" {
    bucket = "ddyyconsulting-terraform-states"
    endpoints = {
      # Get the namespace
      # oci os ns get --query 'data' --raw-output
      # https://<namespace>.compat.objectstorage.<region>.oraclecloud.com
      s3 = "https://axbasucxrqax.compat.objectstorage.il-jerusalem-1.oraclecloud.com"
    }
    key                         = "terraform-oci-free-tier-infra/terraform.tfstate"
    profile                     = "ddyyconsulting"
    region                      = "il-jerusalem-1"
    shared_credentials_files    = ["~/.oci/config"]
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

provider "oci" {
  config_file_profile = local.profile_name
}
