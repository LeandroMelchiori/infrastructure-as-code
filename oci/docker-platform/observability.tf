module "observability" {
  source = "../modules/observability"

  providers = {
    oci = oci
  }

  compartment_ocid                   = var.compartment_ocid
  project_name                       = var.project_name
  server_name                        = local.server_name
  instance_id                        = oci_core_instance.server.id
  monitoring_enabled                 = var.monitoring_enabled
  notification_topic_name            = local.notification_topic_name
  notification_protocol              = var.notification_protocol
  notification_endpoint              = var.notification_endpoint
  cpu_alarm_threshold_percent        = var.cpu_alarm_threshold_percent
  cpu_alarm_pending_duration_minutes = var.cpu_alarm_pending_duration_minutes
  cpu_alarm_severity                 = var.cpu_alarm_severity
  common_tags                        = local.common_tags
}
