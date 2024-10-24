terraform {
  required_version = ">= 1.8.4"

  backend "s3" {
    bucket                      = "langburd-terraform-states"
    endpoints                   = { s3 = "https://fr2sanzp1w2c.compat.objectstorage.eu-frankfurt-1.oraclecloud.com" }
    key                         = "terraform.tfstate"
    profile                     = "langburd"
    region                      = "eu-frankfurt-1"
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
      version = "~> 6.15.0"
    }
  }
}

provider "oci" {
  config_file_profile = local.profile_name
}
