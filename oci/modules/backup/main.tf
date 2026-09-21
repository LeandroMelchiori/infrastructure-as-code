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

  freeform_tags = var.common_tags
}

resource "oci_core_volume_backup_policy_assignment" "boot" {
  count = var.backup_enabled ? 1 : 0

  asset_id  = var.boot_volume_id
  policy_id = oci_core_volume_backup_policy.boot[0].id
}
