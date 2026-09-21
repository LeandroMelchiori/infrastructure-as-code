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
