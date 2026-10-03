output "server_id" {
  description = "OCID de la instancia"
  value       = oci_core_instance.server.id

  precondition {
    condition = (
      var.environment_name == "dev" ||
      !contains(["0.0.0.0/0", "::/0"], var.ssh_source_cidr)
    )
    error_message = "staging y prod no permiten SSH desde 0.0.0.0/0 o ::/0."
  }

  precondition {
    condition = (
      var.environment_name != "prod" ||
      (
        var.monitoring_enabled &&
        var.logging_enabled &&
        var.backup_enabled &&
        var.registry_enabled &&
        var.registry_visibility == "PRIVATE" &&
        var.registry_immutable == true &&
        var.object_storage_access_type == "NoPublicAccess" &&
        var.object_storage_versioning &&
        var.https_enabled
      )
    )
    error_message = "prod requiere monitoring, logging, backups, registry privado e inmutable, Object Storage privado con versionado y HTTPS."
  }

  precondition {
    condition = (
      !var.https_enabled ||
      (
        var.acme_email != null &&
        can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acme_email))
      )
    )
    error_message = "acme_email debe contener un email válido cuando https_enabled es true."
  }

  precondition {
    condition = (
      !var.object_storage_lifecycle_enabled ||
      var.object_storage_archive_after_days != null ||
      var.object_storage_delete_previous_versions_after_days != null ||
      var.object_storage_abort_multipart_uploads_after_days != null
    )
    error_message = "Al habilitar object_storage_lifecycle_enabled debe configurarse al menos una regla lifecycle."
  }

  precondition {
    condition = (
      !var.object_storage_lifecycle_enabled ||
      var.object_storage_delete_previous_versions_after_days == null ||
      var.object_storage_versioning
    )
    error_message = "object_storage_versioning debe ser true para eliminar versiones anteriores."
  }

  precondition {
    condition     = !var.logging_enabled || length(var.logging_sources) > 0
    error_message = "logging_sources debe contener al menos una fuente cuando logging_enabled es true."
  }

  precondition {
    condition     = !var.registry_enabled || length(var.registry_repository_names) > 0
    error_message = "registry_repository_names debe contener al menos un nombre cuando registry_enabled es true."
  }

  precondition {
    condition     = !var.deployment_enabled || (var.registry_enabled && var.registry_immutable == true)
    error_message = "registry_enabled y registry_immutable deben ser true cuando deployment_enabled es true."
  }

  precondition {
    condition = alltrue(flatten([
      for principal in values(var.deployment_principals) : [
        for repository_name in principal.repository_names :
        contains(var.registry_repository_names, repository_name)
      ]
    ]))
    error_message = "Todos los repositorios autorizados deben existir en registry_repository_names."
  }

  precondition {
    condition     = !var.monitoring_enabled || try(length(trimspace(var.notification_endpoint)) > 0, false)
    error_message = "notification_endpoint debe definirse cuando monitoring_enabled es true."
  }
}

output "server_public_ip" {
  description = "IP pública reservada"
  value       = oci_core_public_ip.server.ip_address
}

output "https_enabled" {
  description = "Indica si Traefik publica HTTPS y gestiona certificados ACME"
  value       = var.https_enabled
}

output "public_endpoint_scheme" {
  description = "Esquema esperado para acceder a las aplicaciones"
  value       = var.https_enabled ? "https" : "http"
}

output "server_private_ip" {
  description = "IP privada del servidor"
  value       = data.oci_core_private_ips.server.private_ips[0].ip_address
}

output "vcn_id" {
  description = "OCID de la VCN"
  value       = module.network.vcn_id
}

output "subnet_id" {
  description = "OCID de la subnet pública"
  value       = module.network.public_subnet_id
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
  value       = module.storage.media_bucket_name
}

output "media_bucket_access_type" {
  description = "Tipo de acceso configurado para el bucket"
  value       = module.storage.media_bucket_access_type
}

output "media_bucket_versioning" {
  description = "Estado del versionado del bucket media"
  value       = module.storage.media_bucket_versioning
}

output "object_storage_lifecycle_policy_id" {
  description = "ID de la política lifecycle del bucket media, o null si está deshabilitada"
  value       = module.storage.object_storage_lifecycle_policy_id
}

output "external_object_storage_policy_id" {
  description = "OCID de la policy para buckets externos, o null si no hay accesos configurados"
  value       = try(oci_identity_policy.server_external_object_storage[0].id, null)
}

output "external_object_storage_grants" {
  description = "Accesos declarados para buckets externos, sin credenciales"
  value = {
    for name, grant in var.external_object_storage_buckets : name => {
      compartment_ocid = grant.compartment_ocid
      bucket_name      = grant.bucket_name
      access           = grant.access
    }
  }
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
  value       = module.backup.boot_volume_backup_policy_id
}

output "boot_volume_backup_policy_assignment_id" {
  description = "OCID de la asignación de backup del boot volume, o null si está deshabilitada"
  value       = module.backup.boot_volume_backup_policy_assignment_id
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
  value       = module.logging.log_group_id
}

output "logs_created" {
  description = "Logs personalizados creados, indexados por fuente"
  value       = module.logging.logs_created
}

output "logging_agent_configuration_ids" {
  description = "OCIDs de las configuraciones del Unified Monitoring Agent"
  value       = module.logging.logging_agent_configuration_ids
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
  value       = module.registry.registry_repository_count
}

output "registry_immutable" {
  description = "Indica si los repositorios OCIR impiden sobrescribir imagenes existentes"
  value       = var.registry_immutable
}

output "registry_repository_names" {
  description = "Nombres de los repositorios OCIR creados"
  value       = module.registry.registry_repository_names
}

output "registry_repository_urls" {
  description = "URLs completas de los repositorios OCIR, indexadas por nombre"
  value       = module.registry.registry_repository_urls
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
