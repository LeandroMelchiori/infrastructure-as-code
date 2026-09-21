# OCI Boot Volume Backup

Módulo local reutilizable que crea una policy personalizada de OCI Block Volume
y la asigna a un boot volume recibido por input.

El módulo conserva el control opcional mediante `backup_enabled`, una única
programación configurable y outputs nulos cuando Backup está deshabilitado. No
crea backups individuales ni administra su lifecycle fuera de la policy de OCI.

El módulo no configura providers, credenciales, IAM, Compute ni backends. El
root module conserva defaults, validaciones, configuración por entorno y outputs
públicos.
