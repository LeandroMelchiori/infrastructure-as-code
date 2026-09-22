# Registry

Módulo local para administrar el conjunto opcional de repositorios de OCI
Container Registry de una arquitectura.

El módulo hereda el provider OCI del root. No configura credenciales, backend,
IAM ni autenticación de Docker. La policy de pull, el Dynamic Group, Compute y
el namespace compartido permanecen bajo la orquestación del root.

## Comportamiento

- Crea un repositorio por cada clave de `registry_repository_names` cuando
  `registry_enabled` es `true`.
- Conserva la inmutabilidad nullable; `null` no se convierte en `false`.
- Combina tags comunes y específicos, permitiendo que los específicos mantengan
  la precedencia existente.
- Construye las URLs con el namespace calculado por cada repositorio.

El módulo no crea imágenes ni concede permisos IAM.
