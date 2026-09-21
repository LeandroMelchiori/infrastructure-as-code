variable "environment_name" {
  description = "Entorno aislado de esta instancia de la plataforma"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name debe ser dev, staging o prod y no tiene valor por defecto."
  }

  validation {
    condition = (
      var.environment_name == "dev" ||
      !contains(["0.0.0.0/0", "::/0"], var.ssh_source_cidr)
    )
    error_message = "staging y prod no permiten SSH desde 0.0.0.0/0 o ::/0."
  }

  validation {
    condition = (
      var.environment_name != "prod" ||
      (
        var.monitoring_enabled &&
        var.logging_enabled &&
        var.backup_enabled &&
        var.registry_enabled &&
        var.registry_visibility == "PRIVATE" &&
        var.registry_immutable == true &&
        var.object_storage_access_type == "NoPublicAccess" &&
        var.object_storage_versioning
      )
    )
    error_message = "prod requiere monitoring, logging, backups, registry privado e inmutable y Object Storage privado con versionado."
  }
}

