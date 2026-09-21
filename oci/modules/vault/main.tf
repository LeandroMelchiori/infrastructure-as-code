resource "oci_kms_vault" "platform" {
  compartment_id = var.compartment_ocid

  display_name = "${var.project_name}-vault"
  vault_type   = "DEFAULT"

  freeform_tags = var.common_tags
}

resource "oci_kms_key" "platform" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-key"
  management_endpoint = oci_kms_vault.platform.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  protection_mode          = "SOFTWARE"
  is_auto_rotation_enabled = false

  freeform_tags = var.common_tags
}
