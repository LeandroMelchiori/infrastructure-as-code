resource "oci_identity_compartment" "platform" {
  compartment_id = var.parent_compartment_ocid

  name        = var.platform_compartment_name
  description = var.platform_compartment_description

  enable_delete = false
  freeform_tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}
