variable "compartment_ocid" {
  description = "OCID del compartment donde se crea Network Core"
  type        = string
}

variable "project_name" {
  description = "Nombre estable utilizado en los recursos OCI"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR de la VCN validado por el root"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet pública validado por el root"
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
