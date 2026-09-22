resource "oci_logging_log_group" "platform" {
  count = var.logging_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.log_group_name
  description    = "Logs de infraestructura para ${var.project_name}"

  freeform_tags = var.common_tags
}

resource "oci_logging_log" "platform" {
  for_each = var.enabled_logging_sources

  display_name       = "${var.project_name}-${each.key}"
  log_group_id       = oci_logging_log_group.platform[0].id
  log_type           = "CUSTOM"
  is_enabled         = true
  retention_duration = var.logging_retention_days

  freeform_tags = merge(var.common_tags, {
    LogSource = each.key
  })
}

resource "oci_logging_unified_agent_configuration" "platform" {
  for_each = var.enabled_logging_sources

  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${each.key}-logs"
  description    = "Recolección de logs ${each.key} para ${var.project_name}"
  is_enabled     = true

  group_association {
    group_list = [var.dynamic_group_id]
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

  freeform_tags = merge(var.common_tags, {
    LogSource = each.key
  })
}
