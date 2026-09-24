resource "oci_identity_policy" "application_storage" {
  compartment_id = var.tenancy_ocid

  name        = "${var.project_name}-object-storage-policy"
  description = "Acceso minimo del grupo de aplicacion al bucket ${module.storage.media_bucket_name}"

  statements = [
    "Allow group ${var.iam_group_name} to read buckets in compartment ${var.compartment_name} where target.bucket.name = '${module.storage.media_bucket_name}'",
    "Allow group ${var.iam_group_name} to manage objects in compartment ${var.compartment_name} where all {target.bucket.name = '${module.storage.media_bucket_name}', any {${join(", ", [for permission in local.object_permissions : "request.permission = '${permission}'"])}}}"
  ]
}
