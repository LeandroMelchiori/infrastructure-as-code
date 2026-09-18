# AGENTS.md

Guía para agentes que trabajen en este repositorio de Infrastructure as Code.

## Propósito del repositorio

Este repositorio documenta y versiona plantillas de infraestructura reutilizables. Cada carpeta de proveedor debe tratarse como una infraestructura independiente, con su propia documentación, variables de ejemplo y flujo de despliegue.

Las infraestructuras actualmente implementadas son:

- `oci/terraform-state`: bootstrap independiente para un bucket privado y versionado dedicado al estado remoto de Terraform.
- `oci/docker-platform`: plataforma Docker sobre Oracle Cloud Infrastructure con VCN, subnet pública, NSG, Reserved Public IP, Compute, cloud-init, Docker, Traefik, Vault, KMS, IAM Instance Principal y Object Storage.

## Estructura relevante

```text
infrastructure-as-code/
├── README.md
├── AGENTS.md
├── .gitignore
└── oci/
    ├── terraform-state/
    │   ├── README.md
    │   ├── *.tf
    │   └── terraform.tfvars.example
    └── docker-platform/
        ├── README.md
        ├── *.tf
        ├── backend.oci.tfbackend.example
        ├── terraform.tfvars.example
        ├── cloud-init/
        │   └── bootstrap.yaml.tftpl
        └── proxy/
            └── docker-compose.yml.tftpl
```

## Convenciones generales

- Mantén la documentación en español, siguiendo el tono claro y operativo de los README existentes.
- Conserva la separación entre infraestructura y aplicaciones. No agregues apps concretas a `oci/docker-platform`; esa plantilla solo prepara la plataforma base.
- Usa nombres derivados de `project_name` cuando agregues recursos nuevos, salvo que exista una variable explícita para permitir override.
- Aplica `local.common_tags` a recursos OCI nuevos cuando el provider lo soporte.
- Prefiere variables declaradas en `variables.tf` antes que valores fijos dentro de recursos.
- Mantén `terraform.tfvars.example` como documentación segura y sin secretos reales.

## Terraform

Trabaja desde la carpeta de la infraestructura concreta:

```bash
cd oci/docker-platform
cp backend.oci.tfbackend.example backend.oci.tfbackend
terraform init -backend-config=backend.oci.tfbackend
terraform fmt -recursive
terraform validate
terraform plan
```

Para el bootstrap del bucket trabaja desde `oci/terraform-state` y utiliza
`terraform init` sin backend remoto.

Requisitos actuales:

- Terraform `>= 1.12.0`
- Provider `oracle/oci` versión `8.29.0`
- Autenticación OCI por defecto: `InstancePrincipal`
- Región por defecto: `sa-saopaulo-1`

`oci/terraform-state` es una arquitectura bootstrap: crea el bucket antes de que
las demás configuraciones puedan inicializar su backend. Conserva su propio state
local, que debe tratarse como un archivo sensible y respaldarse fuera de Git.

Antes de entregar cambios en Terraform:

- Ejecuta `terraform fmt -recursive` en la raíz del módulo modificado.
- Ejecuta `terraform validate` si el entorno tiene provider y credenciales disponibles.
- Ejecuta `terraform plan` solo cuando sea seguro consultar OCI y existan variables locales válidas.
- Si no puedes ejecutar una validación por falta de credenciales, provider, red o `terraform.tfvars`, indícalo explícitamente.

## Archivos sensibles y estado

No agregues ni sugieras commitear:

- `terraform.tfvars`
- `*.auto.tfvars`
- `*.tfstate`
- `*.tfstate.*`
- `*.tfplan`
- `*.tfbackend`
- `.terraform/`
- `.env`
- `.env.*`
- `*.pem`
- `*.key`

El archivo `terraform.tfvars.example` sí debe mantenerse versionado y solo debe contener placeholders.

## Seguridad y operaciones destructivas

Este repositorio crea infraestructura real en OCI. Actúa con cautela:

- No ejecutes `terraform apply` ni `terraform destroy` salvo petición explícita del usuario.
- No amplíes permisos IAM sin explicar el motivo y el alcance.
- Evita abrir SSH a `0.0.0.0/0` como recomendación productiva; úsalo solo como ejemplo de laboratorio, tal como indica la documentación.
- Trata cambios en CIDR, subnets, VCN, KMS, Vault, buckets, boot volumes, dynamic groups y policies como potencialmente disruptivos.
- Revisa especialmente cualquier cambio en `preserve_boot_volume`, `access_type`, `object_storage_versioning`, reglas NSG y políticas IAM.

## OCI Docker Platform

La carpeta `oci/docker-platform` define:

- `network.tf`: VCN, Internet Gateway, route table, security list y subnet pública.
- `security.tf`: NSG del servidor, reglas públicas HTTP/HTTPS, SSH configurable y egress.
- `compute.tf`: instancia Oracle Linux 9, shape flexible, VNIC, Reserved Public IP y `cloud-init`.
- `iam.tf`: Dynamic Group e IAM Policy para leer secretos y acceder al bucket.
- `vault.tf`: OCI Vault y KMS Key.
- `storage.tf`: bucket de Object Storage para archivos de aplicaciones.
- `observability.tf`: topic, suscripción y alarma opcionales para monitoreo de CPU.
- `backend.oci.tfbackend.example`: ejemplo sin credenciales para configurar el backend remoto dedicado.
- `locals.tf`: nombres derivados y tags comunes.
- `outputs.tf`: salidas principales de compute, red, Vault, KMS y Object Storage.
- `cloud-init/bootstrap.yaml.tftpl`: instalación de Docker, OCI CLI, firewalld, estructura `/opt/apps` y arranque de Traefik.
- `proxy/docker-compose.yml.tftpl`: Traefik con Docker provider, red externa `proxy`, HTTP->HTTPS y Let's Encrypt HTTP-01.

## Bootstrap y servidor

El bootstrap espera una instancia Oracle Linux 9 y realiza, entre otras cosas:

- instalación de Docker Engine y Docker Compose plugin;
- instalación de OCI CLI;
- activación de `docker` y `firewalld`;
- apertura de SSH, HTTP y HTTPS en firewalld;
- creación de `/opt/apps/proxy`, `/opt/apps/shared` y `/opt/apps/apps`;
- creación de la red Docker externa `proxy`;
- arranque de Traefik con `docker compose up -d`.

Cuando edites `bootstrap.yaml.tftpl` o `docker-compose.yml.tftpl`, revisa que el contenido siga siendo compatible con `templatefile` y con la codificación base64 usada en `compute.tf`.

## Variables importantes

Variables requeridas o de alto impacto:

- `tenancy_ocid`
- `compartment_ocid`
- `compartment_name`
- `project_name`
- `oci_auth`
- `oci_config_file_profile`
- `acme_email`
- `ssh_public_key_path`
- `ssh_source_cidr`
- `shape`
- `ocpus`
- `memory_in_gbs`
- `boot_volume_size_in_gbs`
- `image_ocid`
- `media_bucket_name`
- `object_storage_access_type`
- `object_storage_versioning`
- `monitoring_enabled`
- `notification_topic_name`
- `notification_protocol`
- `notification_endpoint`
- `cpu_alarm_threshold_percent`
- `cpu_alarm_pending_duration_minutes`
- `cpu_alarm_severity`

Si agregas variables:

- Define `description` y `type`.
- Agrega `default` solo cuando exista un valor seguro y reutilizable.
- Usa bloques `validation` para opciones cerradas o peligrosas.
- Actualiza `terraform.tfvars.example`.
- Actualiza el README del módulo si cambia el flujo de uso.

## IAM, Vault y Object Storage

La instancia usa Instance Principal mediante Dynamic Group. No agregues credenciales OCI estáticas al servidor, a contenedores ni a ejemplos.

El bucket de Terraform State pertenece a `oci/terraform-state`; no concedas acceso
a ese bucket al Dynamic Group del servidor ni lo combines con el bucket `media`.

La policy actual permite:

- leer `secret-bundles` en el compartment configurado;
- leer el bucket de medios;
- gestionar objetos dentro del bucket de medios.

Si modificas permisos, mantén el alcance mínimo necesario y prefiere condiciones por nombre de bucket u otro criterio específico cuando sea posible.

## Documentación

Actualiza documentación cuando cambies:

- recursos creados;
- variables;
- outputs;
- comandos de uso;
- reglas de seguridad;
- estructura generada en el servidor;
- supuestos sobre OCI, Docker, Traefik, Vault, KMS u Object Storage.

El README raíz debe seguir describiendo el catálogo general. El README dentro de cada infraestructura debe contener los detalles de esa plantilla.

## Estilo de cambios

- Mantén cambios pequeños y centrados.
- No reformatees archivos no relacionados.
- No elimines comentarios o documentación útil sin reemplazarla por algo mejor.
- Antes de tocar archivos, revisa si hay cambios locales existentes.
- Si encuentras cambios no tuyos, trabaja alrededor de ellos y no los reviertas.

## Comandos útiles

Desde la raíz del repositorio:

```bash
rg --files
git status --short
```

Desde `oci/docker-platform`:

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform output
```

Usa `terraform apply` y `terraform destroy` únicamente cuando el usuario lo pida de forma explícita.
