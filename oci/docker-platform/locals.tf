locals {
  server_name = "${var.project_name}-server"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
