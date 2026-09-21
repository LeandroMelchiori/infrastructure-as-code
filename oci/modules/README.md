# Módulos OCI

Módulos locales reutilizables consumidos por las arquitecturas OCI del
repositorio. No contienen providers configurados, backends ni credenciales.

- `observability`: alarma de CPU, topic y suscripción de Notifications.
- `vault`: OCI Vault y KMS Key con configuración criptográfica estable.
- `backup`: policy administrada y asignación de backup para un boot volume.
- `storage`: bucket media y lifecycle policy opcional de Object Storage.
- `network`: VCN, Internet Gateway, routing, security list y subnet pública.

La modularización se realiza de forma incremental. Cada migración debe conservar
los nombres remotos, añadir bloques `moved` en el root consumidor y comprobar los
planes de todos sus entornos antes de cualquier apply controlado.
