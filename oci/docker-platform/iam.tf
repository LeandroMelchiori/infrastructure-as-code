resource "oci_identity_dynamic_group" "server" {
  compartment_id = var.tenancy_ocid

  name        = "${var.project_name}-server-dg"
  description = "Instance Principal para ${local.server_name}"

  matching_rule = "instance.id = '${oci_core_instance.server.id}'"
}

resource "oci_identity_policy" "server_secrets" {
  compartment_id = var.tenancy_ocid

  name = "${var.project_name}-server-policy"

  description = "Permite al servidor acceder a secretos y objetos del proyecto"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to read secret-bundles in compartment ${var.compartment_name}",

    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to read buckets in compartment ${var.compartment_name} where target.bucket.name = '${module.storage.media_bucket_name}'",

    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to manage objects in compartment ${var.compartment_name} where target.bucket.name = '${module.storage.media_bucket_name}'"
  ]
}
