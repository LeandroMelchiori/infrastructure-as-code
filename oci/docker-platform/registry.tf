resource "oci_artifacts_container_repository" "platform" {
  for_each = var.registry_enabled ? var.registry_repository_names : toset([])

  compartment_id = var.compartment_ocid
  display_name   = each.value
  is_immutable   = var.registry_immutable
  is_public      = var.registry_visibility == "PUBLIC"

  freeform_tags = merge(local.common_tags, var.registry_freeform_tags)
}

resource "oci_identity_policy" "registry_pull" {
  count = var.registry_enabled ? 1 : 0

  compartment_id = var.tenancy_ocid

  name        = "${var.project_name}-registry-pull-policy"
  description = "Permite al servidor descargar imagenes privadas desde OCIR"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to read repos in compartment ${var.compartment_name}"
  ]
}
