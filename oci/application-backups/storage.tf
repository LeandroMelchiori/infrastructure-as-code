data "oci_objectstorage_namespace" "backups" {}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.backups.namespace

  name = var.bucket_name

  access_type  = "NoPublicAccess"
  storage_tier = "Standard"
  versioning   = "Disabled"

  object_events_enabled = false

  freeform_tags = local.common_tags
}

# La retencion la aplica el propio Object Storage: borra cada backup a los retention_days dias.
resource "oci_objectstorage_object_lifecycle_policy" "backups" {
  namespace = data.oci_objectstorage_namespace.backups.namespace
  bucket    = oci_objectstorage_bucket.backups.name

  rules {
    action      = "DELETE"
    is_enabled  = true
    name        = "delete-backups-after-retention"
    target      = "objects"
    time_amount = tostring(var.retention_days)
    time_unit   = "DAYS"
  }

  rules {
    action      = "ABORT"
    is_enabled  = true
    name        = "abort-incomplete-multipart-uploads"
    target      = "multipart-uploads"
    time_amount = "1"
    time_unit   = "DAYS"
  }

  # Object Storage necesita su propio permiso para ejecutar las reglas.
  depends_on = [oci_identity_policy.backups]
}
