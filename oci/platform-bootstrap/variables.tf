variable "parent_compartment_ocid" {
  description = "OCID del tenancy o compartment padre donde se creara la plataforma"
  type        = string

  validation {
    condition = can(regex(
      "^ocid1\\.(tenancy|compartment)\\.",
      trimspace(var.parent_compartment_ocid)
    ))
    error_message = "parent_compartment_ocid debe ser un OCID de tenancy o compartment valido."
  }
}

variable "platform_compartment_name" {
  description = "Nombre del nuevo compartment dedicado a la plataforma de aplicaciones"
  type        = string

  validation {
    condition = can(regex(
      "^[A-Za-z][A-Za-z0-9_-]{0,99}$",
      var.platform_compartment_name
    ))
    error_message = "platform_compartment_name debe comenzar con una letra y usar solo letras, numeros, guion o guion bajo."
  }
}

variable "platform_compartment_description" {
  description = "Descripcion del compartment de plataforma"
  type        = string
  default     = "Infraestructura compartida para aplicaciones propias"

  validation {
    condition     = length(trimspace(var.platform_compartment_description)) > 0
    error_message = "platform_compartment_description no puede estar vacia."
  }
}

variable "state_bucket_name" {
  description = "Nombre unico del bucket privado dedicado a Terraform State"
  type        = string

  validation {
    condition     = length(trimspace(var.state_bucket_name)) > 0
    error_message = "state_bucket_name no puede estar vacio."
  }
}

variable "region" {
  description = "Region OCI para los recursos regionales del bootstrap"
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
  description = "Perfil OCI usado por APIKey o SecurityToken"
  type        = string
  default     = "DEFAULT"
}

variable "freeform_tags" {
  description = "Tags adicionales para el compartment y el bucket de state"
  type        = map(string)
  default     = {}
  nullable    = false
}
