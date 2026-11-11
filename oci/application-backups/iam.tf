resource "oci_identity_policy" "backups" {
  compartment_id = var.tenancy_ocid

  name        = "${var.project_name}-backups-policy"
  description = "Acceso minimo de la instancia y del ciclo de vida al bucket de backups ${var.bucket_name}"

  statements = [
    "Allow dynamic-group ${var.dynamic_group_name} to read buckets in compartment ${var.compartment_name} where target.bucket.name = '${var.bucket_name}'",
    "Allow dynamic-group ${var.dynamic_group_name} to manage objects in compartment ${var.compartment_name} where all {target.bucket.name = '${var.bucket_name}', any {${join(", ", [for permission in local.object_permissions : "request.permission = '${permission}'"])}}}",
    "Allow service objectstorage-${var.region} to manage object-family in compartment ${var.compartment_name} where target.bucket.name = '${var.bucket_name}'"
  ]
}
