# OCI Observability

Módulo local reutilizable para una alarma de CPU de OCI Monitoring conectada a
un topic y una suscripción de OCI Notifications.

El módulo no configura providers, credenciales ni backends. El root module debe
proporcionar el OCID de la instancia, nombres ya resueltos, configuración de la
alarma, endpoint sensible y tags. Cuando `monitoring_enabled = false`, no crea
recursos y sus outputs de recursos devuelven `null`.

La validación de perfiles `dev`, `staging` y `prod` permanece en el root module.
