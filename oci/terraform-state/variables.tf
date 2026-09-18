variable "compartment_ocid" {
  description = "OCID del compartment donde se creará el bucket de Terraform State"
  type        = string
}

variable "state_bucket_name" {
  description = "Nombre globalmente único del bucket dedicado a Terraform State"
  type        = string

  validation {
    condition     = length(trimspace(var.state_bucket_name)) > 0
    error_message = "state_bucket_name no puede estar vacío."
  }
}

variable "region" {
  description = "Región OCI del bucket"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "oci_auth" {
  description = "Método de autenticación del provider OCI"
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
  description = "Perfil del archivo de configuración OCI, usado por APIKey o SecurityToken"
  type        = string
  default     = "DEFAULT"
}
