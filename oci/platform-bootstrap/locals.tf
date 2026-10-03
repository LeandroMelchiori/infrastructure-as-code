locals {
  common_tags = merge(var.freeform_tags, {
    ManagedBy = "Terraform"
    Purpose   = "ApplicationPlatformBootstrap"
  })
}
