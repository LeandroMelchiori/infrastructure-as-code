locals {
  backup_periods = {
    DAILY   = "ONE_DAY"
    WEEKLY  = "ONE_WEEK"
    MONTHLY = "ONE_MONTH"
  }
}

resource "oci_core_volume_backup_policy" "boot" {
  count = var.backup_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-boot-backup"

  schedules {
    backup_type       = var.backup_type
    period            = local.backup_periods[var.backup_frequency]
    retention_seconds = var.backup_retention_days * 86400
    offset_type       = "STRUCTURED"
    hour_of_day       = var.backup_hour_utc
    day_of_week       = var.backup_frequency == "WEEKLY" ? var.backup_day_of_week : null
    day_of_month      = var.backup_frequency == "MONTHLY" ? var.backup_day_of_month : null
    time_zone         = "UTC"
  }

  freeform_tags = local.common_tags
}

resource "oci_core_volume_backup_policy_assignment" "boot" {
  count = var.backup_enabled ? 1 : 0

  asset_id  = oci_core_instance.server.boot_volume_id
  policy_id = oci_core_volume_backup_policy.boot[0].id
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
