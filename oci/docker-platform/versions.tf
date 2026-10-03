terraform {
  required_version = ">= 1.5.7, < 2.0.0"

  backend "oci" {}

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.29.0"
    }
  }
}
