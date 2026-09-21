output "notification_topic_id" {
  description = "OCID del topic, o null cuando monitoring está deshabilitado"
  value       = try(oci_ons_notification_topic.alerts[0].id, null)
}

output "notification_subscription_id" {
  description = "OCID de la suscripción, o null cuando monitoring está deshabilitado"
  value       = try(oci_ons_subscription.alerts[0].id, null)
}

output "notification_subscription_state" {
  description = "Estado de la suscripción, o null cuando monitoring está deshabilitado"
  value       = try(oci_ons_subscription.alerts[0].state, null)
}

output "cpu_alarm_id" {
  description = "OCID de la alarma de CPU, o null cuando monitoring está deshabilitado"
  value       = try(oci_monitoring_alarm.high_cpu[0].id, null)
}
