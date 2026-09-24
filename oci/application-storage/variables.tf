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
  description = "Nombre estable y unico del bucket de documentos de la aplicacion"
  type        = string

  validation {
    condition     = length(trimspace(var.bucket_name)) > 0
    error_message = "bucket_name no puede estar vacio."
  }
}

variable "iam_group_name" {
  description = "Grupo IAM preexistente que recibe acceso al bucket; admite nombre o dominio/nombre"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$", var.iam_group_name))
    error_message = "iam_group_name solo puede contener letras, numeros, punto, guion, guion bajo y un separador de dominio opcional."
  }
}

variable "object_storage_versioning" {
  description = "Activa versionado del bucket; desactivado por defecto para el MVP"
  type        = bool
  default     = false
}

variable "allow_object_overwrite" {
  description = "Permite sobrescribir objetos existentes sin conceder permisos de borrado"
  type        = bool
  default     = false
}

variable "freeform_tags" {
  description = "Tags adicionales no sensibles aplicados al bucket"
  type        = map(string)
  default     = {}
}
