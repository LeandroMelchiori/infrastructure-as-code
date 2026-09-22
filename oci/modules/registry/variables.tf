variable "registry_enabled" {
  description = "Crea los repositorios configurados"
  type        = bool
}

variable "compartment_ocid" {
  description = "OCID del compartment donde se crean los repositorios"
  type        = string
}

variable "registry_repository_names" {
  description = "Nombres estables de los repositorios OCIR"
  type        = set(string)
}

variable "registry_visibility" {
  description = "Visibilidad común de los repositorios"
  type        = string
}

variable "registry_immutable" {
  description = "Control opcional de inmutabilidad; null conserva el comportamiento administrado por OCI"
  type        = bool
  nullable    = true
}

variable "registry_freeform_tags" {
  description = "Tags específicos aplicados a los repositorios"
  type        = map(string)
}

variable "common_tags" {
  description = "Tags comunes de la plataforma"
  type        = map(string)
}

variable "registry_domain" {
  description = "Endpoint regional de OCIR usado para construir las URLs"
  type        = string
}
