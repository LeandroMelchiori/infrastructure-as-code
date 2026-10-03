# Arquitecturas de referencia OCI

Este directorio documenta cómo combinar root modules y módulos reutilizables del
repositorio para resolver escenarios completos. Una arquitectura de referencia
no es un root module adicional y no posee state.

## Catálogo

| Arquitectura | Uso | Estado |
|---|---|---|
| [Single VM Multi App](./single-vm-multi-app/) | Plataforma OCI económica para ejecutar varias aplicaciones propias sobre una VM con Docker Compose y Traefik | Validada en dev |

## Reglas

- Los archivos `.tf` canónicos permanecen en sus root modules y en
  `oci/modules`.
- Cada root module conserva su propio state y ciclo de vida.
- Los ejemplos contienen placeholders y nunca OCIDs, credenciales, state o
  archivos de backend reales.
- Un caso práctico registra una ejecución concreta; una arquitectura de
  referencia explica cómo reproducir el patrón para otro proyecto.
- Los cambios funcionales se realizan primero en el root module propietario y
  después se actualiza la documentación de composición.

El despliegue que originó la primera referencia está registrado en
[`oci/case-studies/nuevamente-dev-oci.md`](../case-studies/nuevamente-dev-oci.md).
