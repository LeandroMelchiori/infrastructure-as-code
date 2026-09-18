variable "tenancy_ocid" {
  description = "OCID del tenancy OCI"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID del compartment donde se desplegará la plataforma"
  type        = string
}

variable "compartment_name" {
  description = "Nombre del compartment, utilizado por las políticas IAM"
  type        = string
}

variable "project_name" {
  description = "Nombre corto del proyecto o plataforma"
  type        = string
}

variable "region" {
  description = "Región OCI"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "oci_auth" {
  description = "Método de autenticación del provider OCI"
  type        = string
  default     = "InstancePrincipal"
}

variable "oci_config_file_profile" {
  description = "Perfil del archivo de configuración OCI, usado por APIKey o SecurityToken"
  type        = string
  default     = "DEFAULT"
}

variable "vcn_cidr" {
  description = "CIDR de la VCN"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet pública"
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
  default     = "~/.ssh/cloudshellkey.pub"
}

variable "ssh_source_cidr" {
  description = "CIDR autorizado para conectarse por SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "shape" {
  description = "Shape de la instancia OCI"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Cantidad de OCPU"
  type        = number
  default     = 2
}

variable "memory_in_gbs" {
  description = "RAM de la instancia"
  type        = number
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Tamaño del disco de arranque"
  type        = number
  default     = 50
}

variable "image_ocid" {
  description = "OCID opcional de una imagen Oracle Linux fijada. null usa la más reciente."
  type        = string
  default     = null
}

variable "acme_email" {
  description = "Email utilizado por Let's Encrypt"
  type        = string
}

variable "traefik_image" {
  description = "Imagen Docker utilizada para Traefik"
  type        = string
  default     = "traefik:v3.7.13"
}

variable "media_bucket_name" {
  description = "Nombre opcional del bucket para imágenes y archivos. Si es null se genera a partir de project_name."
  type        = string
  default     = null
}

variable "object_storage_access_type" {
  description = "Nivel de acceso público del bucket"
  type        = string
  default     = "NoPublicAccess"

  validation {
    condition = contains([
      "NoPublicAccess",
      "ObjectRead",
      "ObjectReadWithoutList"
    ], var.object_storage_access_type)

    error_message = "object_storage_access_type debe ser NoPublicAccess, ObjectRead u ObjectReadWithoutList."
  }
}

variable "object_storage_versioning" {
  description = "Activa el versionado de objetos del bucket"
  type        = bool
  default     = false
}
