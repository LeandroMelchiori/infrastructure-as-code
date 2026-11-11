variable "tenancy_ocid" {
  description = "OCID de la tenancy donde se crea la policy IAM"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID del compartment donde se crea el bucket"
  type        = string
}

variable "compartment_name" {
  description = "Nombre exacto del compartment usado en las sentencias IAM"
  type        = string

  validation {
    condition     = length(trimspace(var.compartment_name)) > 0
    error_message = "compartment_name no puede estar vacio."
  }
}

variable "project_name" {
  description = "Nombre estable del proyecto usado para nombres y tags"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$", var.project_name))
    error_message = "project_name debe tener entre 3 y 30 caracteres en minusculas, numeros o guiones."
  }
}

variable "region" {
  description = "Region OCI del bucket"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "oci_auth" {
  description = "Metodo de autenticacion del provider OCI"
  type        = string
  default     = "InstancePrincipal"

  validation {
    condition = contains([
      "APIKey",
      "InstancePrincipal",
      "ResourcePrincipal",
      "SecurityToken",
      "OKEWorkloadIdentity"
    ], var.oci_auth)

    error_message = "oci_auth debe ser APIKey, InstancePrincipal, ResourcePrincipal, SecurityToken u OKEWorkloadIdentity."
  }
}

variable "oci_config_file_profile" {
  description = "Perfil del archivo OCI usado por APIKey o SecurityToken"
  type        = string
  default     = "DEFAULT"
}

variable "bucket_name" {
  description = "Nombre estable y unico del bucket de backups de la aplicacion"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,256}$", var.bucket_name))
    error_message = "bucket_name solo puede contener letras, numeros, punto, guion y guion bajo."
  }
}

variable "dynamic_group_name" {
  description = "Dynamic group preexistente de la instancia que sube los backups; admite nombre o dominio/nombre"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$", var.dynamic_group_name))
    error_message = "dynamic_group_name solo puede contener letras, numeros, punto, guion, guion bajo y un separador de dominio opcional."
  }
}

variable "retention_days" {
  description = "Dias que se conserva cada backup antes de que la regla de ciclo de vida lo borre"
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 3650 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days debe ser un entero entre 1 y 3650."
  }
}

variable "allow_read" {
  description = "Permite que la instancia descargue backups para probar restauraciones"
  type        = bool
  default     = true
}

variable "freeform_tags" {
  description = "Tags adicionales no sensibles aplicados al bucket"
  type        = map(string)
  default     = {}
}
