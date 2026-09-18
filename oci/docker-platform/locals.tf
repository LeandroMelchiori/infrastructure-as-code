locals {
  server_name = "${var.project_name}-server"

  media_bucket_name = (
    var.media_bucket_name != null
    ? var.media_bucket_name
    : "${var.project_name}-media"
  )

  notification_topic_name = (
    var.notification_topic_name != null
    ? var.notification_topic_name
    : "${var.project_name}-alerts"
  )

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
