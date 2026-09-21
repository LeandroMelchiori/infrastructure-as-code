# OCI Object Storage

Módulo local reutilizable que crea un bucket media y, opcionalmente, su lifecycle
policy. El namespace se recibe desde el root para que pueda compartirse con otros
componentes de la arquitectura.

Conserva un bucket Standard, object events deshabilitados, versioning
configurable y reglas opcionales para archivar objetos, eliminar versiones
anteriores y abortar multipart uploads incompletos.

El módulo no configura providers, credenciales, IAM, aplicaciones ni backends.
El root module conserva nombres derivados, defaults, validaciones, configuración
por entorno y outputs públicos.
