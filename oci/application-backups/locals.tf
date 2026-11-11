locals {
  common_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "application-backups"
    },
    var.freeform_tags
  )

  # Sin OBJECT_DELETE ni OBJECT_OVERWRITE: una instancia comprometida no puede borrar ni pisar backups.
  object_permissions = concat(
    [
      "OBJECT_INSPECT",
      "OBJECT_CREATE"
    ],
    var.allow_read ? ["OBJECT_READ"] : []
  )
}
