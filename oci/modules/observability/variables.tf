variable "compartment_ocid" {
  description = "OCID del compartment donde se crean Monitoring y Notifications"
  type        = string
}

variable "project_name" {
  description = "Nombre estable del proyecto utilizado en nombres y descripciones"
  type        = string
}

variable "server_name" {
  description = "Nombre de la instancia incluida en el mensaje de la alarma"
  type        = string
}

variable "instance_id" {
  description = "OCID de la instancia Compute monitoreada"
  type        = string
}

variable "monitoring_enabled" {
  description = "Habilita el topic, la suscripción y la alarma de CPU"
  type        = bool
}

variable "notification_topic_name" {
  description = "Nombre del topic de OCI Notifications"
  type        = string
}

variable "notification_protocol" {
  description = "Protocolo de entrega de la suscripción"
  type        = string
}

variable "notification_endpoint" {
  description = "Endpoint de la suscripción; puede ser null cuando el módulo está deshabilitado"
  type        = string
  sensitive   = true
}

variable "cpu_alarm_threshold_percent" {
  description = "Umbral porcentual de CPU que activa la alarma"
  type        = number
}

variable "cpu_alarm_pending_duration_minutes" {
  description = "Minutos durante los que debe mantenerse el umbral"
  type        = number
}

variable "cpu_alarm_severity" {
  description = "Severidad OCI asignada a la alarma"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes aplicados a los recursos compatibles"
  type        = map(string)
  nullable    = false
  default = {
    ManagedBy = "terraform"
  }

  validation {
    condition     = length(var.common_tags) > 0
    error_message = "common_tags debe contener al menos un tag."
  }
}
