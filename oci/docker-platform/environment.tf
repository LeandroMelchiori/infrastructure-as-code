variable "environment_name" {
  description = "Entorno aislado de esta instancia de la plataforma"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name debe ser dev, staging o prod y no tiene valor por defecto."
  }

}

