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
