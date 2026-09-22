variable "logging_enabled" {
  description = "Crea el Log Group opcional"
  type        = bool
}

variable "compartment_ocid" {
  description = "OCID del compartment para los recursos de Logging"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto usado en nombres y descripciones"
  type        = string
}

variable "log_group_name" {
  description = "Nombre resuelto del Log Group"
  type        = string
}

variable "logging_retention_days" {
  description = "Retención de los logs personalizados en días"
  type        = number
}

variable "enabled_logging_sources" {
  description = "Fuentes de logs habilitadas, indexadas por nombre estable"
  type = map(object({
    paths       = list(string)
    parser_type = string
  }))
}

variable "dynamic_group_id" {
  description = "OCID del Dynamic Group asociado al Unified Monitoring Agent"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes aplicados a los recursos de Logging"
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
