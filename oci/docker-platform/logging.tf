locals {
  logging_log_group_name = (
    var.logging_log_group_name != null
    ? var.logging_log_group_name
    : "${var.project_name}-logs"
  )

  logging_source_definitions = {
    system = {
      paths = [
        "/var/log/messages*",
        "/var/log/secure*",
        "/var/log/dmesg*"
      ]
      parser_type = "NONE"
    }
    "cloud-init" = {
      paths = [
        "/var/log/cloud-init.log",
        "/var/log/cloud-init-output.log"
      ]
      parser_type = "NONE"
    }
    docker = {
      paths       = ["/var/lib/docker/containers/*/*-json.log"]
      parser_type = "JSON"
    }
  }

  enabled_logging_sources = var.logging_enabled ? {
    for name, configuration in local.logging_source_definitions :
    name => configuration
    if contains(var.logging_sources, name)
  } : {}
}

module "logging" {
  source = "../modules/logging"

  providers = {
    oci = oci
  }

  logging_enabled         = var.logging_enabled
  compartment_ocid        = var.compartment_ocid
  project_name            = var.project_name
  log_group_name          = local.logging_log_group_name
  logging_retention_days  = var.logging_retention_days
  enabled_logging_sources = local.enabled_logging_sources
  dynamic_group_id        = oci_identity_dynamic_group.server.id
  common_tags             = local.common_tags

  depends_on = [oci_identity_policy.logging_ingestion]
}

resource "oci_identity_policy" "logging_ingestion" {
  count = var.logging_enabled ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-logging-policy"
  description    = "Permite al servidor enviar logs de infraestructura a OCI Logging"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to use log-content in compartment ${var.compartment_name}"
  ]
}
