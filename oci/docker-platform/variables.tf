variable "tenancy_ocid" {
  description = "OCID del tenancy OCI"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID del compartment donde se desplegará la plataforma"
  type        = string
}

variable "compartment_name" {
  description = "Nombre del compartment, utilizado por las políticas IAM"
  type        = string
}

variable "project_name" {
  description = "Nombre corto del proyecto o plataforma"
  type        = string
}

variable "region" {
  description = "Región OCI"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "oci_auth" {
  description = "Método de autenticación del provider OCI"
  type        = string
  default     = "InstancePrincipal"
}

variable "oci_config_file_profile" {
  description = "Perfil del archivo de configuración OCI, usado por APIKey o SecurityToken"
  type        = string
  default     = "DEFAULT"
}

variable "vcn_cidr" {
  description = "CIDR de la VCN"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet pública"
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
  default     = "~/.ssh/cloudshellkey.pub"
}

variable "ssh_source_cidr" {
  description = "CIDR autorizado para conectarse por SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "shape" {
  description = "Shape de la instancia OCI"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Cantidad de OCPU"
  type        = number
  default     = 2
}

variable "memory_in_gbs" {
  description = "RAM de la instancia"
  type        = number
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Tamaño del disco de arranque"
  type        = number
  default     = 50
}

variable "image_ocid" {
  description = "OCID opcional de una imagen Oracle Linux fijada. null usa la más reciente."
  type        = string
  default     = null
}

variable "acme_email" {
  description = "Email utilizado por Let's Encrypt"
  type        = string
}

variable "traefik_image" {
  description = "Imagen Docker utilizada para Traefik"
  type        = string
  default     = "traefik:v3.7.13"
}

variable "media_bucket_name" {
  description = "Nombre opcional del bucket para imágenes y archivos. Si es null se genera a partir de project_name."
  type        = string
  default     = null
}

variable "object_storage_access_type" {
  description = "Nivel de acceso público del bucket"
  type        = string
  default     = "NoPublicAccess"

  validation {
    condition = contains([
      "NoPublicAccess",
      "ObjectRead",
      "ObjectReadWithoutList"
    ], var.object_storage_access_type)

    error_message = "object_storage_access_type debe ser NoPublicAccess, ObjectRead u ObjectReadWithoutList."
  }
}

variable "object_storage_versioning" {
  description = "Activa el versionado de objetos del bucket"
  type        = bool
  default     = false
}

variable "object_storage_lifecycle_enabled" {
  description = "Crea una política lifecycle opcional para el bucket media"
  type        = bool
  default     = false

  validation {
    condition = (
      !var.object_storage_lifecycle_enabled ||
      var.object_storage_archive_after_days != null ||
      var.object_storage_delete_previous_versions_after_days != null ||
      var.object_storage_abort_multipart_uploads_after_days != null
    )
    error_message = "Al habilitar object_storage_lifecycle_enabled debe configurarse al menos una regla lifecycle."
  }

  validation {
    condition = (
      !var.object_storage_lifecycle_enabled ||
      var.object_storage_delete_previous_versions_after_days == null ||
      var.object_storage_versioning
    )
    error_message = "object_storage_versioning debe ser true para eliminar versiones anteriores."
  }
}

variable "object_storage_archive_after_days" {
  description = "Días antes de archivar objetos actuales; null desactiva la regla"
  type        = number
  default     = null

  validation {
    condition = var.object_storage_archive_after_days == null ? true : (
      (var.object_storage_archive_after_days >= 1 && floor(var.object_storage_archive_after_days) == var.object_storage_archive_after_days)
    )
    error_message = "object_storage_archive_after_days debe ser null o un entero mayor o igual que 1."
  }
}

variable "object_storage_delete_previous_versions_after_days" {
  description = "Días antes de eliminar versiones anteriores; null desactiva la regla destructiva"
  type        = number
  default     = null

  validation {
    condition = var.object_storage_delete_previous_versions_after_days == null ? true : (
      (
        var.object_storage_delete_previous_versions_after_days >= 1 &&
        floor(var.object_storage_delete_previous_versions_after_days) == var.object_storage_delete_previous_versions_after_days
      )
    )
    error_message = "object_storage_delete_previous_versions_after_days debe ser null o un entero mayor o igual que 1."
  }
}

variable "object_storage_abort_multipart_uploads_after_days" {
  description = "Días antes de abortar multipart uploads incompletos; null desactiva la limpieza"
  type        = number
  default     = null

  validation {
    condition = var.object_storage_abort_multipart_uploads_after_days == null ? true : (
      (
        var.object_storage_abort_multipart_uploads_after_days >= 1 &&
        floor(var.object_storage_abort_multipart_uploads_after_days) == var.object_storage_abort_multipart_uploads_after_days
      )
    )
    error_message = "object_storage_abort_multipart_uploads_after_days debe ser null o un entero mayor o igual que 1."
  }
}

variable "backup_enabled" {
  description = "Crea y asigna una política de backup al boot volume de la instancia"
  type        = bool
  default     = false
}

variable "backup_frequency" {
  description = "Frecuencia del backup del boot volume"
  type        = string
  default     = "WEEKLY"

  validation {
    condition     = contains(["DAILY", "WEEKLY", "MONTHLY"], var.backup_frequency)
    error_message = "backup_frequency debe ser DAILY, WEEKLY o MONTHLY."
  }
}

variable "backup_type" {
  description = "Tipo de backup del boot volume"
  type        = string
  default     = "INCREMENTAL"

  validation {
    condition     = contains(["FULL", "INCREMENTAL"], var.backup_type)
    error_message = "backup_type debe ser FULL o INCREMENTAL."
  }
}

variable "backup_retention_days" {
  description = "Cantidad de días que OCI conserva cada backup creado por la política"
  type        = number
  default     = 28

  validation {
    condition = (
      var.backup_retention_days >= 1 &&
      var.backup_retention_days <= 3650 &&
      floor(var.backup_retention_days) == var.backup_retention_days
    )
    error_message = "backup_retention_days debe ser un entero entre 1 y 3650."
  }
}

variable "backup_hour_utc" {
  description = "Hora UTC de inicio del backup, entre 0 y 23"
  type        = number
  default     = 2

  validation {
    condition     = var.backup_hour_utc >= 0 && var.backup_hour_utc <= 23 && floor(var.backup_hour_utc) == var.backup_hour_utc
    error_message = "backup_hour_utc debe ser un entero entre 0 y 23."
  }
}

variable "backup_day_of_week" {
  description = "Día UTC utilizado cuando backup_frequency es WEEKLY"
  type        = string
  default     = "SUNDAY"

  validation {
    condition = contains([
      "MONDAY",
      "TUESDAY",
      "WEDNESDAY",
      "THURSDAY",
      "FRIDAY",
      "SATURDAY",
      "SUNDAY"
    ], var.backup_day_of_week)
    error_message = "backup_day_of_week debe ser un día de la semana en inglés y mayúsculas."
  }
}

variable "backup_day_of_month" {
  description = "Día UTC del mes utilizado cuando backup_frequency es MONTHLY"
  type        = number
  default     = 1

  validation {
    condition     = var.backup_day_of_month >= 1 && var.backup_day_of_month <= 28 && floor(var.backup_day_of_month) == var.backup_day_of_month
    error_message = "backup_day_of_month debe ser un entero entre 1 y 28."
  }
}

variable "logging_enabled" {
  description = "Crea la capa opcional de OCI Logging para la infraestructura"
  type        = bool
  default     = false
}

variable "logging_log_group_name" {
  description = "Nombre opcional del Log Group. Si es null se genera a partir de project_name."
  type        = string
  default     = null

  validation {
    condition     = var.logging_log_group_name == null ? true : length(trimspace(var.logging_log_group_name)) > 0
    error_message = "logging_log_group_name debe ser null o un nombre no vacío."
  }
}

variable "logging_retention_days" {
  description = "Retención de los logs en días, en incrementos de 30 hasta 180"
  type        = number
  default     = 30

  validation {
    condition     = contains([30, 60, 90, 120, 150, 180], var.logging_retention_days)
    error_message = "logging_retention_days debe ser 30, 60, 90, 120, 150 o 180."
  }
}

variable "logging_sources" {
  description = "Fuentes de logs habilitadas cuando logging_enabled es true"
  type        = set(string)
  default     = ["system", "cloud-init", "docker"]

  validation {
    condition = length(setsubtract(
      var.logging_sources,
      toset(["system", "cloud-init", "docker"])
    )) == 0
    error_message = "logging_sources solo admite system, cloud-init y docker."
  }

  validation {
    condition     = !var.logging_enabled || length(var.logging_sources) > 0
    error_message = "logging_sources debe contener al menos una fuente cuando logging_enabled es true."
  }
}

variable "registry_enabled" {
  description = "Crea repositorios privados en OCI Container Registry y habilita pulls con Instance Principal"
  type        = bool
  default     = false
}

variable "registry_repository_names" {
  description = "Nombres genericos de los repositorios OCIR; su longitud determina la cantidad creada"
  type        = set(string)
  default     = []

  validation {
    condition     = !var.registry_enabled || length(var.registry_repository_names) > 0
    error_message = "registry_repository_names debe contener al menos un nombre cuando registry_enabled es true."
  }

  validation {
    condition = alltrue([
      for name in var.registry_repository_names : can(regex("^[a-z0-9]+([._/-][a-z0-9]+)*$", name))
    ])
    error_message = "Los repositorios deben usar minusculas, numeros y separadores '.', '_', '-' o '/'."
  }
}

variable "registry_visibility" {
  description = "Visibilidad comun de los repositorios OCIR"
  type        = string
  default     = "PRIVATE"

  validation {
    condition     = contains(["PRIVATE", "PUBLIC"], var.registry_visibility)
    error_message = "registry_visibility debe ser PRIVATE o PUBLIC."
  }
}

variable "registry_immutable" {
  description = "Control opcional de inmutabilidad OCIR; null preserva la configuracion existente"
  type        = bool
  default     = null
}

variable "registry_freeform_tags" {
  description = "Tags libres adicionales aplicados a todos los repositorios OCIR"
  type        = map(string)
  default     = {}
}

variable "deployment_enabled" {
  description = "Prepara IAM y cloud-init para deployments restringidos mediante OCI Run Command"
  type        = bool
  default     = false

  validation {
    condition     = !var.deployment_enabled || (var.registry_enabled && var.registry_immutable == true)
    error_message = "registry_enabled y registry_immutable deben ser true cuando deployment_enabled es true."
  }
}

variable "deployment_principals" {
  description = "Principales IAM existentes y repositorios exactos que cada uno puede publicar"
  type = map(object({
    principal_type   = string
    principal_name   = string
    repository_names = set(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for principal in values(var.deployment_principals) :
      contains(["group", "dynamic-group"], principal.principal_type)
    ])
    error_message = "principal_type debe ser group o dynamic-group."
  }

  validation {
    condition = alltrue([
      for key, principal in var.deployment_principals :
      can(regex("^[a-z0-9][a-z0-9-]{0,31}$", key)) &&
      can(regex("^[A-Za-z0-9_-]+$", principal.principal_name)) &&
      length(principal.repository_names) > 0
    ])
    error_message = "Cada principal necesita una clave simple, un nombre IAM valido y al menos un repositorio."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.deployment_principals) : [
        for repository_name in principal.repository_names :
        contains(var.registry_repository_names, repository_name)
      ]
    ]))
    error_message = "Todos los repositorios autorizados deben existir en registry_repository_names."
  }
}

variable "monitoring_enabled" {
  description = "Crea la alarma de CPU y los recursos de OCI Notifications"
  type        = bool
  default     = false
}

variable "notification_topic_name" {
  description = "Nombre opcional del topic de alertas. Si es null se genera a partir de project_name."
  type        = string
  default     = null

  validation {
    condition     = var.notification_topic_name == null ? true : length(trimspace(var.notification_topic_name)) > 0
    error_message = "notification_topic_name debe ser null o un nombre no vacío."
  }
}

variable "notification_protocol" {
  description = "Protocolo de la suscripción de OCI Notifications"
  type        = string
  default     = "EMAIL"

  validation {
    condition = contains([
      "CUSTOM_HTTPS",
      "EMAIL",
      "ORACLE_FUNCTIONS",
      "PAGERDUTY",
      "SLACK",
      "SMS"
    ], var.notification_protocol)

    error_message = "notification_protocol debe ser CUSTOM_HTTPS, EMAIL, ORACLE_FUNCTIONS, PAGERDUTY, SLACK o SMS."
  }
}

variable "notification_endpoint" {
  description = "Endpoint de la suscripción. Su formato depende de notification_protocol."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = !var.monitoring_enabled || try(length(trimspace(var.notification_endpoint)) > 0, false)
    error_message = "notification_endpoint debe definirse cuando monitoring_enabled es true."
  }
}

variable "cpu_alarm_threshold_percent" {
  description = "Porcentaje de CPU a partir del cual se activa la alarma"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_alarm_threshold_percent > 0 && var.cpu_alarm_threshold_percent <= 100
    error_message = "cpu_alarm_threshold_percent debe ser mayor que 0 y menor o igual que 100."
  }
}

variable "cpu_alarm_pending_duration_minutes" {
  description = "Minutos que debe mantenerse el umbral antes de activar la alarma"
  type        = number
  default     = 5

  validation {
    condition = (
      var.cpu_alarm_pending_duration_minutes >= 1 &&
      var.cpu_alarm_pending_duration_minutes <= 60 &&
      floor(var.cpu_alarm_pending_duration_minutes) == var.cpu_alarm_pending_duration_minutes
    )
    error_message = "cpu_alarm_pending_duration_minutes debe ser un entero entre 1 y 60."
  }
}

variable "cpu_alarm_severity" {
  description = "Severidad de la alarma de CPU"
  type        = string
  default     = "WARNING"

  validation {
    condition     = contains(["CRITICAL", "ERROR", "WARNING", "INFO"], var.cpu_alarm_severity)
    error_message = "cpu_alarm_severity debe ser CRITICAL, ERROR, WARNING o INFO."
  }
}
