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

variable "ssh_source_cidr" {
  description = "CIDR autorizado por el root para conexiones SSH"
  type        = string
}

variable "public_web_ports" {
  description = "Puertos web públicos indexados por nombre lógico"
  type        = map(number)
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
