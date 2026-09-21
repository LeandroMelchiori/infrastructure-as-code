variable "compartment_ocid" {
  description = "OCID del compartment donde se crea el bucket"
  type        = string
}

variable "namespace" {
  description = "Namespace de OCI Object Storage"
  type        = string
}

variable "bucket_name" {
  description = "Nombre estable del bucket"
  type        = string
}

variable "access_type" {
  description = "Tipo de acceso validado por el root"
  type        = string
}

variable "versioning" {
  description = "Activa el versionado de objetos"
  type        = bool
}

variable "common_tags" {
  description = "Tags comunes aplicados al bucket"
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

variable "lifecycle_enabled" {
  description = "Crea la lifecycle policy opcional"
  type        = bool
}

variable "archive_after_days" {
  description = "Días antes de archivar objetos actuales, o null"
  type        = number
}

variable "delete_previous_versions_after_days" {
  description = "Días antes de eliminar versiones anteriores, o null"
  type        = number
}

variable "abort_multipart_uploads_after_days" {
  description = "Días antes de abortar multipart uploads incompletos, o null"
  type        = number
}
