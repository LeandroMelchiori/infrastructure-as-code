variable "compartment_ocid" {
  description = "OCID del compartment donde se crean Vault y KMS"
  type        = string
}

variable "project_name" {
  description = "Nombre estable del proyecto utilizado en los nombres OCI"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes aplicados al Vault y a la KMS Key"
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
