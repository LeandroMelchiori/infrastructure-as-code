locals {
  common_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "application-content"
    },
    var.freeform_tags
  )

  object_permissions = concat(
    [
      "OBJECT_INSPECT",
      "OBJECT_READ",
      "OBJECT_CREATE"
    ],
    var.allow_object_overwrite ? ["OBJECT_OVERWRITE"] : []
  )
}
