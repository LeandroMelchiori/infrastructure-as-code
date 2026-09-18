output "server_id" {
  description = "OCID de la instancia"
  value       = oci_core_instance.server.id
}

output "server_public_ip" {
  description = "IP pública reservada"
  value       = oci_core_public_ip.server.ip_address
}

output "server_private_ip" {
  description = "IP privada del servidor"
  value       = data.oci_core_private_ips.server.private_ips[0].ip_address
}

output "vcn_id" {
  description = "OCID de la VCN"
  value       = oci_core_vcn.platform.id
}

output "subnet_id" {
  description = "OCID de la subnet pública"
  value       = oci_core_subnet.public.id
}

output "vault_id" {
  description = "OCID del Vault"
  value       = oci_kms_vault.platform.id
}

output "key_id" {
  description = "OCID de la KMS Key"
  value       = oci_kms_key.platform.id
}

output "object_storage_namespace" {
  description = "Namespace de OCI Object Storage"
  value       = data.oci_objectstorage_namespace.platform.namespace
}

output "media_bucket_name" {
  description = "Nombre del bucket utilizado para imágenes y archivos"
  value       = oci_objectstorage_bucket.media.name
}

output "media_bucket_access_type" {
  description = "Tipo de acceso configurado para el bucket"
  value       = oci_objectstorage_bucket.media.access_type
}

output "monitoring_enabled" {
  description = "Indica si la observabilidad opcional está habilitada"
  value       = var.monitoring_enabled
}

output "notification_topic_id" {
  description = "OCID del topic de OCI Notifications, o null si el monitoreo está deshabilitado"
  value       = try(oci_ons_notification_topic.alerts[0].id, null)
}

output "notification_subscription_id" {
  description = "OCID de la suscripción de alertas, o null si el monitoreo está deshabilitado"
  value       = try(oci_ons_subscription.alerts[0].id, null)
}

output "notification_subscription_state" {
  description = "Estado de la suscripción de alertas, o null si el monitoreo está deshabilitado"
  value       = try(oci_ons_subscription.alerts[0].state, null)
}

output "cpu_alarm_id" {
  description = "OCID de la alarma de CPU, o null si el monitoreo está deshabilitado"
  value       = try(oci_monitoring_alarm.high_cpu[0].id, null)
}
