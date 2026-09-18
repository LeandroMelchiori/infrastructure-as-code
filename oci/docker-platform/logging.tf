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

resource "oci_logging_log_group" "platform" {
  count = var.logging_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = local.logging_log_group_name
  description    = "Logs de infraestructura para ${var.project_name}"

  freeform_tags = local.common_tags
}

resource "oci_logging_log" "platform" {
  for_each = local.enabled_logging_sources

  display_name       = "${var.project_name}-${each.key}"
  log_group_id       = oci_logging_log_group.platform[0].id
  log_type           = "CUSTOM"
  is_enabled         = true
  retention_duration = var.logging_retention_days

  freeform_tags = merge(local.common_tags, {
    LogSource = each.key
  })
}

resource "oci_logging_unified_agent_configuration" "platform" {
  for_each = local.enabled_logging_sources

  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${each.key}-logs"
  description    = "Recolección de logs ${each.key} para ${var.project_name}"
  is_enabled     = true

  group_association {
    group_list = [oci_identity_dynamic_group.server.id]
  }

  service_configuration {
    configuration_type = "LOGGING"

    destination {
      log_object_id = oci_logging_log.platform[each.key].id
    }

    sources {
      source_type = "LOG_TAIL"
      name        = "${var.project_name}-${each.key}"
      paths       = each.value.paths

      advanced_options {
        is_read_from_head = false
      }

      parser {
        parser_type = each.value.parser_type
      }
    }
  }

  freeform_tags = merge(local.common_tags, {
    LogSource = each.key
  })

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
