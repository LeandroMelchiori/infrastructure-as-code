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
