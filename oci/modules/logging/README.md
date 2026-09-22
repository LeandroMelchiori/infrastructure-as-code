# Logging

Módulo local para la capa opcional de OCI Logging. Administra el Log Group, los
logs personalizados y las configuraciones del Unified Monitoring Agent.

El módulo hereda el provider OCI del root y no configura credenciales ni
backend. El root conserva las definiciones de fuentes, sus variables públicas,
el Dynamic Group y la policy IAM de ingestión.

## Dependencias

El root entrega el OCID del Dynamic Group mediante `dynamic_group_id`. La llamada
al módulo depende de la policy IAM de ingestión para asegurar que el permiso
exista antes de crear las configuraciones del agente. Esta dependencia en el
nivel del módulo ordena también el Log Group y los logs, sin cambiar sus
argumentos ni su comportamiento remoto.

## Recursos

- `oci_logging_log_group.platform`, opcional mediante `logging_enabled`.
- `oci_logging_log.platform`, uno por entrada de `enabled_logging_sources`.
- `oci_logging_unified_agent_configuration.platform`, uno por la misma clave.

Cuando Logging está deshabilitado, `log_group_id` es `null` y los mapas de logs
y configuraciones del agente están vacíos.
