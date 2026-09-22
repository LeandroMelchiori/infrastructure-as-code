output "log_group_id" {
  description = "OCID del Log Group, o null si logging está deshabilitado"
  value       = try(oci_logging_log_group.platform[0].id, null)
}

output "logs_created" {
  description = "Logs personalizados creados, indexados por fuente"
  value = {
    for name, log in oci_logging_log.platform : name => {
      id           = log.id
      display_name = log.display_name
      state        = log.state
    }
  }
}

output "logging_agent_configuration_ids" {
  description = "OCIDs de las configuraciones del Unified Monitoring Agent"
  value = {
    for name, configuration in oci_logging_unified_agent_configuration.platform :
    name => configuration.id
  }
}
