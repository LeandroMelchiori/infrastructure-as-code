locals {
  server_name = "${var.project_name}-server"

  media_bucket_name = (
    var.media_bucket_name != null
    ? var.media_bucket_name
    : "${var.project_name}-media"
  )

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
