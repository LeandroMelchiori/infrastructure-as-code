resource "oci_objectstorage_bucket" "media" {
  compartment_id = var.compartment_ocid
  namespace      = var.namespace

  name = var.bucket_name

  access_type  = var.access_type
  storage_tier = "Standard"

  versioning = var.versioning ? "Enabled" : "Disabled"

  object_events_enabled = false

  freeform_tags = var.common_tags
}

resource "oci_objectstorage_object_lifecycle_policy" "media" {
  count = var.lifecycle_enabled ? 1 : 0

  namespace = var.namespace
  bucket    = oci_objectstorage_bucket.media.name

  dynamic "rules" {
    for_each = var.archive_after_days == null ? [] : [var.archive_after_days]

    content {
      action      = "ARCHIVE"
      is_enabled  = true
      name        = "archive-current-objects"
      target      = "objects"
      time_amount = tostring(rules.value)
      time_unit   = "DAYS"
    }
  }

  dynamic "rules" {
    for_each = var.delete_previous_versions_after_days == null ? [] : [var.delete_previous_versions_after_days]

    content {
      action      = "DELETE"
      is_enabled  = true
      name        = "delete-previous-object-versions"
      target      = "previous-object-versions"
      time_amount = tostring(rules.value)
      time_unit   = "DAYS"
    }
  }

  dynamic "rules" {
    for_each = var.abort_multipart_uploads_after_days == null ? [] : [var.abort_multipart_uploads_after_days]

    content {
      action      = "ABORT"
      is_enabled  = true
      name        = "abort-incomplete-multipart-uploads"
      target      = "multipart-uploads"
      time_amount = tostring(rules.value)
      time_unit   = "DAYS"
    }
  }
}
