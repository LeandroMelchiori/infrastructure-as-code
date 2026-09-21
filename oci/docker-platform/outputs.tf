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
  value       = module.vault.vault_id
}

output "key_id" {
  description = "OCID de la KMS Key"
  value       = module.vault.key_id
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

output "media_bucket_versioning" {
  description = "Estado del versionado del bucket media"
  value       = oci_objectstorage_bucket.media.versioning
}

output "object_storage_lifecycle_policy_id" {
  description = "ID de la política lifecycle del bucket media, o null si está deshabilitada"
  value       = try(oci_objectstorage_object_lifecycle_policy.media[0].id, null)
}

output "backup_enabled" {
  description = "Indica si la política de backup del boot volume está habilitada"
  value       = var.backup_enabled
}

output "boot_volume_id" {
  description = "OCID del boot volume asociado a la instancia"
  value       = oci_core_instance.server.boot_volume_id
}

output "boot_volume_backup_policy_id" {
  description = "OCID de la política de backup del boot volume, o null si está deshabilitada"
  value       = try(oci_core_volume_backup_policy.boot[0].id, null)
}

output "boot_volume_backup_policy_assignment_id" {
  description = "OCID de la asignación de backup del boot volume, o null si está deshabilitada"
  value       = try(oci_core_volume_backup_policy_assignment.boot[0].id, null)
}

output "logging_enabled" {
  description = "Indica si la capa de logging centralizado está habilitada"
  value       = var.logging_enabled
}

output "logging_status" {
  description = "Estado lógico de la capa de logging centralizado"
  value       = var.logging_enabled ? "ENABLED" : "DISABLED"
}

output "log_group_id" {
  description = "OCID del Log Group, o null si logging está deshabilitado"
  value       = try(oci_logging_log_group.platform[0].id, null)
}

output "logs_created" {
  description = "Logs personalizados creados, indexados por fuente"
  value = {
    for name, log in oci_logging_log.platform : name => {
      id           = log.id
      display_name = log.display_name
      state        = log.state
    }
  }
}

output "logging_agent_configuration_ids" {
  description = "OCIDs de las configuraciones del Unified Monitoring Agent"
  value = {
    for name, configuration in oci_logging_unified_agent_configuration.platform :
    name => configuration.id
  }
}

output "registry_enabled" {
  description = "Indica si OCI Container Registry esta habilitado"
  value       = var.registry_enabled
}

output "registry_status" {
  description = "Estado logico de la capa de OCI Container Registry"
  value       = var.registry_enabled ? "ENABLED" : "DISABLED"
}

output "registry_namespace" {
  description = "Namespace de la tenancy utilizado por OCIR"
  value       = data.oci_objectstorage_namespace.platform.namespace
}

output "registry_repository_count" {
  description = "Cantidad de repositorios OCIR administrados por esta arquitectura"
  value       = length(oci_artifacts_container_repository.platform)
}

output "registry_immutable" {
  description = "Indica si los repositorios OCIR impiden sobrescribir imagenes existentes"
  value       = var.registry_immutable
}

output "registry_repository_names" {
  description = "Nombres de los repositorios OCIR creados"
  value       = sort(keys(oci_artifacts_container_repository.platform))
}

output "registry_repository_urls" {
  description = "URLs completas de los repositorios OCIR, indexadas por nombre"
  value = {
    for name, repository in oci_artifacts_container_repository.platform :
    name => "${local.registry_domain}/${repository.namespace}/${repository.display_name}"
  }
}

output "deployment_enabled" {
  description = "Indica si la base de CI/CD de aplicaciones esta habilitada"
  value       = var.deployment_enabled
}

output "deployment_status" {
  description = "Estado logico de la base de CI/CD de aplicaciones"
  value       = var.deployment_enabled ? "ENABLED" : "DISABLED"
}

output "deployment_principal_policy_ids" {
  description = "OCIDs de las policies de deployment, indexados por dominio de confianza"
  value = {
    for name, policy in oci_identity_policy.deployment_principal : name => policy.id
  }
}

output "deployment_authorized_repositories" {
  description = "Repositorios OCIR autorizados para cada dominio de confianza"
  value = {
    for name, principal in var.deployment_principals : name => sort(tolist(principal.repository_names))
  }
}

output "monitoring_enabled" {
  description = "Indica si la observabilidad opcional está habilitada"
  value       = var.monitoring_enabled
}

output "notification_topic_id" {
  description = "OCID del topic de OCI Notifications, o null si el monitoreo está deshabilitado"
  value       = module.observability.notification_topic_id
}

output "notification_subscription_id" {
  description = "OCID de la suscripción de alertas, o null si el monitoreo está deshabilitado"
  value       = module.observability.notification_subscription_id
}

output "notification_subscription_state" {
  description = "Estado de la suscripción de alertas, o null si el monitoreo está deshabilitado"
  value       = module.observability.notification_subscription_state
}

output "cpu_alarm_id" {
  description = "OCID de la alarma de CPU, o null si el monitoreo está deshabilitado"
  value       = module.observability.cpu_alarm_id
}
