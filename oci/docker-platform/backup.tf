module "backup" {
  source = "../modules/backup"

  providers = {
    oci = oci
  }

  backup_enabled        = var.backup_enabled
  compartment_ocid      = var.compartment_ocid
  project_name          = var.project_name
  common_tags           = local.common_tags
  boot_volume_id        = oci_core_instance.server.boot_volume_id
  backup_frequency      = var.backup_frequency
  backup_type           = var.backup_type
  backup_retention_days = var.backup_retention_days
  backup_hour_utc       = var.backup_hour_utc
  backup_day_of_week    = var.backup_day_of_week
  backup_day_of_month   = var.backup_day_of_month
}

resource "oci_objectstorage_object_lifecycle_policy" "media" {
  count = var.object_storage_lifecycle_enabled ? 1 : 0

  namespace = data.oci_objectstorage_namespace.platform.namespace
  bucket    = oci_objectstorage_bucket.media.name

  dynamic "rules" {
    for_each = var.object_storage_archive_after_days == null ? [] : [var.object_storage_archive_after_days]

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
    for_each = var.object_storage_delete_previous_versions_after_days == null ? [] : [var.object_storage_delete_previous_versions_after_days]

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
    for_each = var.object_storage_abort_multipart_uploads_after_days == null ? [] : [var.object_storage_abort_multipart_uploads_after_days]

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
