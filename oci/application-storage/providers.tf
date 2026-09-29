provider "oci" {
  auth                = var.oci_auth
  config_file_profile = contains(["APIKey", "SecurityToken"], var.oci_auth) ? var.oci_config_file_profile : null
  region              = var.region
}
