variable "backup_enabled" {
  description = "Crea y asigna la política de backup al boot volume"
  type        = bool
}

variable "compartment_ocid" {
  description = "OCID del compartment donde se crea la política"
  type        = string
}

variable "project_name" {
  description = "Nombre estable del proyecto utilizado en la policy"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes aplicados a la política de backup"
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

variable "boot_volume_id" {
  description = "OCID del boot volume al que se asigna la política"
  type        = string
}

variable "backup_frequency" {
  description = "Frecuencia validada por el root: DAILY, WEEKLY o MONTHLY"
  type        = string
}

variable "backup_type" {
  description = "Tipo de backup validado por el root: FULL o INCREMENTAL"
  type        = string
}

variable "backup_retention_days" {
  description = "Cantidad de días de retención validada por el root"
  type        = number
}

variable "backup_hour_utc" {
  description = "Hora UTC de ejecución validada por el root"
  type        = number
}

variable "backup_day_of_week" {
  description = "Día UTC utilizado para la frecuencia WEEKLY"
  type        = string
}

variable "backup_day_of_month" {
  description = "Día UTC del mes utilizado para la frecuencia MONTHLY"
  type        = number
}
