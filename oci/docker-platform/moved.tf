moved {
  from = oci_ons_notification_topic.alerts
  to   = module.observability.oci_ons_notification_topic.alerts
}

moved {
  from = oci_ons_subscription.alerts
  to   = module.observability.oci_ons_subscription.alerts
}

moved {
  from = oci_monitoring_alarm.high_cpu
  to   = module.observability.oci_monitoring_alarm.high_cpu
}

moved {
  from = oci_kms_vault.platform
  to   = module.vault.oci_kms_vault.platform
}

moved {
  from = oci_kms_key.platform
  to   = module.vault.oci_kms_key.platform
}

moved {
  from = oci_core_volume_backup_policy.boot
  to   = module.backup.oci_core_volume_backup_policy.boot
}

moved {
  from = oci_core_volume_backup_policy_assignment.boot
  to   = module.backup.oci_core_volume_backup_policy_assignment.boot
}

moved {
  from = oci_objectstorage_bucket.media
  to   = module.storage.oci_objectstorage_bucket.media
}

moved {
  from = oci_objectstorage_object_lifecycle_policy.media
  to   = module.storage.oci_objectstorage_object_lifecycle_policy.media
}

moved {
  from = oci_core_vcn.platform
  to   = module.network.oci_core_vcn.platform
}

moved {
  from = oci_core_internet_gateway.platform
  to   = module.network.oci_core_internet_gateway.platform
}

moved {
  from = oci_core_route_table.public
  to   = module.network.oci_core_route_table.public
}

moved {
  from = oci_core_security_list.public
  to   = module.network.oci_core_security_list.public
}

moved {
  from = oci_core_subnet.public
  to   = module.network.oci_core_subnet.public
}
