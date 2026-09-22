module "registry" {
  source = "../modules/registry"

  providers = {
    oci = oci
  }

  registry_enabled          = var.registry_enabled
  compartment_ocid          = var.compartment_ocid
  registry_repository_names = var.registry_repository_names
  registry_visibility       = var.registry_visibility
  registry_immutable        = var.registry_immutable
  registry_freeform_tags    = var.registry_freeform_tags
  common_tags               = local.common_tags
  registry_domain           = local.registry_domain
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
