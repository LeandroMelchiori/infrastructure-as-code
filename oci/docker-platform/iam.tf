resource "oci_identity_dynamic_group" "server" {
  compartment_id = var.tenancy_ocid

  name        = "${var.project_name}-server-dg"
  description = "Instance Principal para ${local.server_name}"

  matching_rule = "instance.id = '${oci_core_instance.server.id}'"
}

resource "oci_identity_policy" "server_secrets" {
  compartment_id = var.tenancy_ocid

  name = "${var.project_name}-server-secrets-policy"

  description = "Permite al servidor leer secretos del proyecto"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to read secret-bundles in compartment ${var.compartment_name}"
  ]
}
