resource "oci_artifacts_container_repository" "platform" {
  for_each = var.registry_enabled ? var.registry_repository_names : toset([])

  compartment_id = var.compartment_ocid
  display_name   = each.value
  is_immutable   = var.registry_immutable
  is_public      = var.registry_visibility == "PUBLIC"

  freeform_tags = merge(var.common_tags, var.registry_freeform_tags)
}
