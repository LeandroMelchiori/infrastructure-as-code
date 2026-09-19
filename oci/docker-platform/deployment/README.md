# Deployment restringido de aplicaciones

Esta carpeta contiene referencias para integrar repositorios de aplicaciones con
la plataforma. Ningun archivo registra una aplicacion automaticamente.

## Limite de confianza

El workflow de una aplicacion solo solicita:

```text
deploy-compose-app <app> <commit-sha>
```

El nombre, repositorio OCIR, servicio, Compose y health check autorizados viven
en la VM bajo `/etc/docker-platform/apps/<app>/`. El pipeline no puede escribir
ese directorio ni proporcionar opciones a Docker.

El wrapper exige exactamente dos argumentos, valida un SHA Git completo, carga
archivos `root:root` sin symlinks, valida un subconjunto cerrado de Compose y
rechaza capacidades peligrosas. Primero valida con una referencia digest
temporal, luego descarga el tag SHA, resuelve el digest real y ejecuta Compose
unicamente con `repository@sha256:...`. El rollback conserva el Compose y el
digest anteriores.

## Registro administrativo

La incorporación de una aplicacion es una operación de plataforma, separada del
workflow. Un administrador debe crear:

```text
/etc/docker-platform/apps/<app>/deployment.json
/etc/docker-platform/apps/<app>/compose.yaml
```

Usa `app-config.example.json` y `compose.example.yml` como referencia. Instala
directorios con modo `0750`, archivos con modo `0640` y propietario
`root:root`. No se admiten symlinks ni rutas configurables.

`deployment.json` tiene un esquema cerrado con cinco campos:

- `repository`: URI completa y sin tag de un repositorio OCIR permitido.
- `service`: servicio de Compose cuya imagen usa `DEPLOY_IMAGE`.
- `compose_file`: nombre simple del archivo local.
- `health_url`: URL fija sin credenciales, query ni fragmento.
- `allowed_images`: imágenes auxiliares OCIR fijadas por digest.

La configuración Compose soportada es deliberadamente pequeña. No admite
`build`, ports publicados, bind mounts, secrets/configs de Compose, devices,
capacidades adicionales ni namespaces del host. Los datos persistentes deben
usar named volumes y el acceso HTTP debe pasar por la red externa de Traefik.

## Instancia existente

Terraform ignora cambios posteriores en `metadata.user_data`, por lo que
habilitar la funcionalidad no reemplaza ni modifica la instancia existente.
Para prepararla, un administrador debe instalar una vez:

```bash
sudo install -o root -g root -m 0755 \
  cloud-init/deploy-compose-app.py /usr/local/sbin/deploy-compose-app

sudo install -d -o root -g root -m 0750 /etc/docker-platform/apps
sudo chown root:root /opt/apps/apps
sudo chmod 0750 /opt/apps/apps
```

También debe instalar y validar esta regla con `visudo -cf`:

```sudoers
Defaults!/usr/local/sbin/deploy-compose-app env_reset,secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ocarun ALL=(root) NOPASSWD: /usr/local/sbin/deploy-compose-app
```

No agregues `ocarun` al grupo `docker` y no le concedas `NOPASSWD:ALL`.

## Autenticacion de GitHub Actions

Terraform no crea usuarios, API keys, auth tokens ni secretos. La variable
`deployment_principals` solo crea policies para principales IAM existentes y
limita cada uno a repositorios exactos ya administrados por Terraform.

La referencia `github-actions/deploy.yml.example` presupone un runner OCI
dedicado y preferentemente efimero, autenticado con Instance Principal. Ese
runner debe tener OCI CLI y `docker-credential-ocir` configurados. Usa un
Dynamic Group separado por aplicacion o dominio de confianza.

OCI Identity Domains permite intercambiar JWT externos por tokens temporales,
pero la integracion directa GitHub OIDC -> OCI/OCIR no es actualmente un flujo
turnkey. La autenticacion se mantiene fuera de este modulo para poder sustituir
el runner por federacion sin cambiar el contrato de deployment.

## Riesgo residual

Una imagen maliciosa todavía puede comprometer los recursos que el Compose
autorizado exponga al contenedor: named volumes, redes, variables de entorno,
servicios accesibles y posibles vulnerabilidades del kernel o runtime. Este
diseño reduce los privilegios del pipeline y bloquea configuraciones host-level,
pero no convierte una imagen maliciosa en segura.

Un workflow comprometido también puede causar indisponibilidad de su aplicación
o solicitar deployments de entradas conocidas. GitHub Environments, revisores
obligatorios, branch protection y principales separados siguen siendo controles
necesarios.
