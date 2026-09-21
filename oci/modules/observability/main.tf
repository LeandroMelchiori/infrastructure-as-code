resource "oci_ons_notification_topic" "alerts" {
  count = var.monitoring_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = var.notification_topic_name
  description    = "Alertas de infraestructura para ${var.project_name}"

  freeform_tags = var.common_tags
}

resource "oci_ons_subscription" "alerts" {
  count = var.monitoring_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.alerts[0].id
  protocol       = var.notification_protocol
  endpoint       = var.notification_endpoint

  freeform_tags = var.common_tags
}

resource "oci_monitoring_alarm" "high_cpu" {
  count = var.monitoring_enabled ? 1 : 0

  compartment_id        = var.compartment_ocid
  metric_compartment_id = var.compartment_ocid

  display_name = "${var.project_name}-high-cpu"
  body         = "La instancia ${var.server_name} superó el umbral de CPU configurado."
  severity     = var.cpu_alarm_severity
  is_enabled   = true

  namespace = "oci_vmi_resource_utilization"
  query = format(
    "CpuUtilization[5m]{resourceId = \"%s\"}.mean() > %g",
    var.instance_id,
    var.cpu_alarm_threshold_percent
  )

  pending_duration = "PT${var.cpu_alarm_pending_duration_minutes}M"
  destinations     = [oci_ons_notification_topic.alerts[0].id]

  freeform_tags = var.common_tags
}
