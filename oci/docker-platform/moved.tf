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

moved {
  from = oci_core_network_security_group.server
  to   = module.network.oci_core_network_security_group.server
}

moved {
  from = oci_core_network_security_group_security_rule.web
  to   = module.network.oci_core_network_security_group_security_rule.web
}

moved {
  from = oci_core_network_security_group_security_rule.ssh
  to   = module.network.oci_core_network_security_group_security_rule.ssh
}

moved {
  from = oci_core_network_security_group_security_rule.egress
  to   = module.network.oci_core_network_security_group_security_rule.egress
}

moved {
  from = oci_logging_log_group.platform
  to   = module.logging.oci_logging_log_group.platform
}

moved {
  from = oci_logging_log.platform
  to   = module.logging.oci_logging_log.platform
}

moved {
  from = oci_logging_unified_agent_configuration.platform
  to   = module.logging.oci_logging_unified_agent_configuration.platform
}
