# OCI Docker Platform

Plantilla reutilizable de Infrastructure as Code para desplegar una plataforma Docker sobre Oracle Cloud Infrastructure.

La infraestructura está diseñada para ser independiente de las aplicaciones. Su objetivo es crear una base Cloud preparada para alojar distintos proyectos containerizados.

---

## Objetivo

Esta arquitectura permite ejecutar:

```bash
terraform init -reconfigure -backend-config=environments/dev/backend.oci.tfbackend
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

y obtener una plataforma OCI configurada con:

- Networking
- Compute
- Seguridad
- IP pública reservada
- IAM
- Vault
- KMS
- Docker
- Docker Compose
- OCI CLI
- OCI Logging
- OCI Monitoring
- OCI Notifications
- OCI Container Registry
- Base restringida para CI/CD de aplicaciones
- firewalld
- Traefik
- Let's Encrypt
- Bootstrap automático mediante cloud-init

La aplicación que luego se despliegue sobre esta plataforma no forma parte de esta infraestructura.

---

## Arquitectura

```text
                        Internet
                           │
                           ▼
                  IP Pública Reservada
                           │
                           ▼
                       OCI VCN
                           │
                           ▼
                    Subred Pública
                           │
                           ▼
                ┌────────────────────┐
                │    OCI Compute     │
                │    Oracle Linux    │
                │      A1 Flex       │
                └─────────┬──────────┘
                          │
                     cloud-init
                          │
            ┌─────────────┼─────────────┐
            │             │             │
            ▼             ▼             ▼
         Docker        OCI CLI       firewalld
            │
            ▼
      Red Docker "proxy"
            │
        ┌───┴──────────────┐
        │                  │
        ▼                  ▼
     Traefik          Aplicaciones
        │
        ├── HTTP → HTTPS
        ├── Let's Encrypt
        └── Docker discovery


                   OCI IAM
                      │
                Dynamic Group
                      │
             Instance Principal
                      │
                      ▼
                  OCI Vault
                      │
                      ▼
                   KMS Key


                OCI Monitoring
                      │
                Alarma de CPU
                      │
                      ▼
             OCI Notifications
                      │
                      ▼
                 Suscripción


                  OCI Logging
                      │
            Unified Monitoring Agent
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       Sistema    cloud-init    Docker
                                  │
                                  ▼
                               Traefik


             OCI Container Registry
                      │
             Repositorios privados
                      │
                      ▼
          Docker credential helper
                      │
                      ▼
             Instance Principal


           Repositorio de aplicación
                      │
                GitHub Actions
                      │
          test -> build -> scan -> push
                      │
                      ▼
                     OCIR
                      │
                OCI Run Command
                      │
                      ▼
         deploy-compose-app <app> <sha>
                      │
         Compose root-owned + digest
                      │
                      ▼
              Traefik + health check
```

---

## Recursos creados

### Networking

Terraform crea:

- Virtual Cloud Network
- Subred pública
- Internet Gateway
- Route Table
- Security List
- Network Security Group
- Reglas de entrada
- Reglas de salida

La red puede configurarse mediante variables.

Ejemplo:

```hcl
vcn_cidr           = "10.20.0.0/16"
public_subnet_cidr = "10.20.1.0/24"
```

---

## Seguridad de red

El Network Security Group permite por defecto:

| Puerto | Protocolo | Uso |
|---|---|---|
| 22 | TCP | SSH |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |

El origen permitido para SSH puede configurarse mediante:

```hcl
ssh_source_cidr = "TU_IP/32"
```

Para entornos de laboratorio también puede utilizarse:

```hcl
ssh_source_cidr = "0.0.0.0/0"
```

En entornos productivos se recomienda restringir este valor.

---

## Compute

La infraestructura crea una instancia OCI Compute.

La configuración predeterminada utiliza:

```hcl
shape = "VM.Standard.A1.Flex"

ocpus         = 2
memory_in_gbs = 12
```

También puede configurarse el tamaño del volumen de arranque:

```hcl
boot_volume_size_in_gbs = 50
```

La clave pública SSH configurada en Terraform se agrega automáticamente a la instancia.

---

## Backups y recuperación

La capa de backup es opcional, genérica y no depende de las aplicaciones
desplegadas en Docker. Permanece deshabilitada por defecto:

```hcl
backup_enabled = false
```

Cuando se habilita, Terraform crea una política personalizada de OCI Block
Volume y la asigna al boot volume de la instancia. Los backups son generados y
expirados por OCI según la programación; Terraform no crea ni conserva recursos
`oci_core_boot_volume_backup` individuales.

Ejemplo conservador semanal:

```hcl
backup_enabled        = true
backup_frequency      = "WEEKLY"
backup_type           = "INCREMENTAL"
backup_retention_days = 28
backup_hour_utc       = 2
backup_day_of_week    = "SUNDAY"
```

También se admiten frecuencias `DAILY` y `MONTHLY`:

```hcl
backup_frequency = "DAILY"

# Para MONTHLY:
# backup_day_of_month = 1
```

La hora y los días se interpretan en UTC. La retención controla cuánto tiempo
OCI conserva cada backup creado por la política. Los tipos permitidos son
`INCREMENTAL` y `FULL`.

Un boot volume solo puede tener una política de backup asignada. Si ya existe
una asignación administrada fuera de este Terraform, revisa el plan antes de
aplicar porque OCI puede reemplazarla por la política declarada aquí.

Deshabilitar `backup_enabled` elimina la asignación y la política administradas
por Terraform, pero no destruye la instancia ni el boot volume. Los backups ya
creados pueden permanecer hasta que expire su retención según el comportamiento
del servicio.

### Recuperación

La restauración es una acción operativa deliberada y no reemplaza
automáticamente la instancia existente. Ante una recuperación:

1. identifica un backup válido del boot volume;
2. crea un nuevo boot volume desde ese backup;
3. valida el volumen restaurado antes de cambiar o recrear la instancia;
4. revisa siempre el plan para evitar reemplazos accidentales.

Por ejemplo, los backups disponibles pueden consultarse con OCI CLI:

```bash
oci bv boot-volume-backup list \
  --compartment-id "<compartment_ocid>" \
  --volume-id "<boot_volume_id>"
```

La automatización de una restauración no forma parte de esta plantilla porque
implica decidir explícitamente qué instancia o volumen debe reemplazarse.

### Protección de Object Storage

El bucket `media` conserva el versionado opcional existente y agrega una
política lifecycle también opcional. Todas las acciones permanecen
deshabilitadas por defecto:

```hcl
object_storage_versioning         = false
object_storage_lifecycle_enabled  = false

object_storage_archive_after_days                    = null
object_storage_delete_previous_versions_after_days   = null
object_storage_abort_multipart_uploads_after_days     = null
```

Las reglas disponibles son:

- archivar objetos actuales después de una cantidad de días;
- eliminar versiones anteriores, solo con versionado habilitado;
- abortar cargas multipart incompletas.

Para habilitar lifecycle debe configurarse al menos una regla. El siguiente
ejemplo protege versiones y limpia únicamente uploads incompletos:

```hcl
object_storage_versioning        = true
object_storage_lifecycle_enabled = true

object_storage_abort_multipart_uploads_after_days = 7
```

La eliminación de versiones anteriores es irreversible y debe habilitarse de
forma explícita. Archivar objetos puede afectar a aplicaciones que esperan
acceso inmediato y puede generar costos de recuperación. Esta arquitectura no
crea Object Retention Rules ni activa bloqueos irreversibles.

### Permisos y costos

No se amplía la IAM del Instance Principal. La identidad que ejecuta Terraform
debe poder administrar políticas de backup, sus asignaciones y lifecycle de
Object Storage en el compartment.

Los backups de boot volumes consumen almacenamiento y pueden generar cargos al
superar las cuotas gratuitas. La frecuencia, el tipo y la retención determinan
cuántas copias se conservan. OCI incluye cinco backups de volumen Always Free en
la home region, compartidos entre boot y block volumes. El ejemplo semanal con
28 días apunta a conservar cuatro, pero los backups de otros volúmenes también
cuentan. Consulta los
[límites Always Free de OCI](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).
El versionado y el archivado también aumentan el almacenamiento facturable;
recuperar objetos archivados puede tener costo.

---

## Logging centralizado

La capa de logging utiliza OCI Logging y permanece deshabilitada por defecto:

```hcl
logging_enabled = false
```

Cuando se habilita, Terraform crea:

- un Log Group;
- un log personalizado por fuente seleccionada;
- una configuración del Unified Monitoring Agent por fuente;
- una política IAM limitada a `use log-content` para el Dynamic Group de la
  instancia.

No se crean recursos ni permisos de logging mientras
`logging_enabled = false`.

### Fuentes

Las fuentes disponibles son:

| Fuente | Rutas | Contenido |
|---|---|---|
| `system` | `/var/log/messages*`, `/var/log/secure*`, `/var/log/dmesg*` | sistema operativo, servicios y eventos de la instancia |
| `cloud-init` | `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log` | bootstrap y diagnóstico de cloud-init |
| `docker` | `/var/lib/docker/containers/*/*-json.log` | stdout y stderr de los contenedores |

Traefik escribe sus logs operativos a stdout mediante la configuración actual,
por lo que se centraliza dentro de la fuente `docker`. Esto evita modificar la
configuración del proxy o conocer aplicaciones concretas.

La fuente `docker` también puede incluir logs de otros contenedores desplegados
en el futuro. No deben escribirse secretos, tokens ni datos personales en stdout.
Si esa política no es apropiada para un entorno, puede excluirse la fuente:

```hcl
logging_enabled = true

logging_sources = [
  "system",
  "cloud-init"
]
```

Configuración completa:

```hcl
logging_enabled        = true
logging_log_group_name = "mi-proyecto-infra-logs"
logging_retention_days = 30

logging_sources = [
  "system",
  "cloud-init",
  "docker"
]
```

La retención admite `30`, `60`, `90`, `120`, `150` o `180` días.
Reducirla hace que los eventos más antiguos dejen de estar disponibles. El
agente comienza a leer desde el final de los archivos para evitar ingerir todo
el historial local al activar logging por primera vez.

### Unified Monitoring Agent

Los logs personalizados de archivos requieren Unified Monitoring Agent. En las
imágenes soportadas de Oracle Linux 9 se distribuye mediante Oracle Cloud Agent
como el plugin `Custom Logs Monitoring`. Los plugins de monitoreo están
habilitados por defecto en OCI salvo que hayan sido desactivados explícitamente.

Puede verificarse el estado desde la VM:

```bash
sudo systemctl status oracle-cloud-agent
sudo systemctl status unified-monitoring-agent
```

También puede revisarse la configuración declarada por OCI:

```bash
oci compute instance get \
  --instance-id "<instance_ocid>" \
  --query 'data."agent-config"."plugins-config"'
```

Si `Custom Logs Monitoring` está deshabilitado, debe habilitarse desde la
configuración de Oracle Cloud Agent en la instancia. La instalación automática
del Unified Monitoring Agent puede tardar varios minutos.

No se modifica `compute.tf`, cloud-init ni Traefik. Activar la capa crea
recursos de control y configuraciones del agente, pero no reemplaza ni reinicia
la instancia. El único impacto sobre la VM es el consumo del agente y la lectura
de los archivos seleccionados.

### IAM y costos

La política opcional concede solamente:

```text
Allow dynamic-group <dynamic-group> to use log-content in compartment <compartment>
```

No concede lectura de logs ni administración de Log Groups a la instancia. La
identidad que ejecuta Terraform sí debe poder administrar recursos de Logging y
la política IAM.

OCI Logging incluye los primeros 10 GB de almacenamiento de logs por mes. El
exceso puede generar cargos; Docker suele ser la fuente de mayor volumen. Revisa
los [precios vigentes de OCI Logging](https://www.oracle.com/manageability/pricing/)
y ajusta fuentes y retención según el entorno.

---

## OCI Container Registry

La capa de registry es opcional, genérica y permanece deshabilitada por defecto:

```hcl
registry_enabled = false
```

Al habilitarla, Terraform crea un repositorio de OCI Container Registry (OCIR)
por cada elemento de `registry_repository_names`. La cantidad se configura
agregando o quitando nombres de ese conjunto; no existe una segunda variable de
conteo que pueda quedar desincronizada.

```hcl
registry_enabled = true

registry_repository_names = [
  "platform/services",
  "platform/workers"
]

registry_visibility = "PRIVATE"
registry_immutable  = null

registry_freeform_tags = {
  Purpose = "application-images"
}
```

Los repositorios son privados por defecto. `PUBLIC` debe elegirse de forma
explícita y permite pulls sin autenticación, por lo que no se recomienda para
imágenes internas. Los tags configurados se combinan con `Project` y
`ManagedBy` de la plataforma.

`registry_immutable` controla la inmutabilidad nativa de OCIR. Se conserva en
`null` por defecto para no administrar ni modificar repositorios existentes,
pero debe ser
`true` al habilitar deployments. En un repositorio inmutable una imagen ya
publicada no puede sobrescribirse, por lo que un tag basado en commit SHA queda
protegido por OCI y no solo por una convención del workflow.

Quitar un nombre o cambiar `registry_enabled` a `false` después de aplicar hace
que Terraform proponga eliminar los repositorios administrados correspondientes.
Revisa siempre el plan y conserva o migra las imágenes antes de aceptar una
operación de ese tipo.

Las URLs usan el endpoint recomendado por OCI:

```text
ocir.<region>.oci.oraclecloud.com/<namespace>/<repository>
```

Terraform publica el namespace, los nombres y las URLs completas como outputs.
La capa de registry no construye ni publica imágenes. La base opcional de
deployment se describe más adelante y permanece separada de estos recursos.

### Autenticación desde Compute

Docker no interpreta Instance Principal directamente. Cuando
`registry_enabled = true`, cloud-init instala `docker-credential-ocir`, configura
Docker para el usuario `opc` y para `root`, y utiliza OCI CLI con Instance
Principal para obtener credenciales temporales. No se ejecuta `docker login` ni
se guardan passwords, auth tokens o credenciales Docker en Terraform, Git o la
VM.

```text
docker pull
     │
     ▼
docker-credential-ocir
     │
     ▼
OCI CLI + Instance Principal
     │
     ▼
credencial temporal de OCIR
```

El helper se compila durante el primer arranque desde una revisión fijada del
proyecto utilizado por el
[tutorial oficial de Oracle](https://docs.oracle.com/en/learn/cred-helper/index.html).
Esto agrega Go al bootstrap cuando el registry está habilitado y requiere salida
HTTPS durante cloud-init.

Para una instancia nueva puede verificarse:

```bash
which docker-credential-ocir
oci iam region list --auth instance_principal
terraform output registry_repository_urls
docker pull ocir.<region>.oci.oraclecloud.com/<namespace>/<repository>:<tag>
```

`registry_repository_urls` es un mapa; selecciona una de sus URLs y agrega el
tag de imagen correspondiente al ejecutar el pull.

OCI no permite actualizar `metadata.user_data` después del lanzamiento. El
recurso Compute ignora deliberadamente cambios posteriores en ese campo para no
reemplazar la instancia. Si se habilita OCIR después del primer arranque,
ejecuta una vez el script `cloud-init/install-ocir-helper.sh.tftpl` con el
endpoint regional sustituido. Una VM creada desde cero con OCIR habilitado lo
instala automáticamente. Terraform no fuerza una recreación.

### IAM, costos y límites

La policy opcional concede al Dynamic Group existente solo:

```text
Allow dynamic-group <dynamic-group> to read repos in compartment <compartment>
```

La instancia puede hacer pull de cualquier repositorio del compartment, pero no
crear repositorios, hacer push ni borrarlos. La identidad que ejecuta Terraform
debe poder administrar repositorios de Artifacts y políticas IAM.

OCIR no tiene un cargo adicional por el servicio, pero el almacenamiento de las
imágenes se factura a la tarifa de Object Storage Standard. Por eso no se debe
asumir que las imágenes están cubiertas por Always Free, aunque los repositorios
vacíos tengan consumo despreciable. La documentación vigente establece límites
regionales de 500 repositorios, 100.000 imágenes por repositorio y 500 GB de
almacenamiento. Consulta el
[resumen de OCIR](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm)
y la [lista de precios](https://www.oracle.com/cloud/price-list/) antes de subir
imágenes de gran tamaño.

---

## Observabilidad y alertas

La observabilidad es opcional y utiliza servicios nativos de OCI sin depender de
ninguna aplicación desplegada en Docker.

Cuando `monitoring_enabled = true`, Terraform crea:

- un topic de OCI Notifications;
- una suscripción configurable;
- una alarma de CPU para la instancia Compute.

La alarma consulta `CpuUtilization` en el namespace agentless
`oci_vmi_resource_utilization` y filtra por el OCID de la instancia. Esta métrica
se obtiene desde el hipervisor, por lo que no requiere modificar la VM ni instalar
software adicional. La ventana de evaluación es de cinco minutos.

```text
OCI Compute
     │
     ▼
CpuUtilization
     │
     ▼
Alarma de CPU
     │
     ▼
Topic de Notifications
     │
     ▼
Email, Custom HTTPS, Slack, PagerDuty, SMS o Function
```

Configuración de ejemplo:

```hcl
monitoring_enabled = true

notification_protocol = "EMAIL"
notification_endpoint = "equipo-operaciones@example.com"

cpu_alarm_threshold_percent        = 80
cpu_alarm_pending_duration_minutes = 5
cpu_alarm_severity                 = "WARNING"
```

El endpoint se define únicamente en el `terraform.tfvars` local del entorno, que está ignorado por
Git, y la variable está marcada como sensible para ocultarla en la salida de
Terraform. El valor seguirá formando parte del state remoto, por lo que el bucket
de state debe permanecer privado. Para evitar cambios sobre instalaciones
existentes, el monitoreo está deshabilitado por defecto.

El nombre predeterminado del topic es `<project_name>-alerts`. Como los nombres
de topics deben ser únicos dentro de la tenancy, puede sobrescribirse:

```hcl
notification_topic_name = "mi-proyecto-produccion-alerts"
```

Las suscripciones que lo requieran deben confirmarse desde el endpoint. Una
suscripción en estado `PENDING` todavía no recibe alertas.

La identidad que ejecuta Terraform debe poder administrar alarmas y topics, y
leer métricas en el compartment. Un ejemplo de permisos para un grupo es:

```text
Allow group <grupo-terraform> to manage alarms in compartment <compartment>
Allow group <grupo-terraform> to read metrics in compartment <compartment>
Allow group <grupo-terraform> to manage ons-topics in compartment <compartment>
```

Deshabilitar `monitoring_enabled` después de haberlo activado elimina la alarma,
la suscripción y el topic en el siguiente `apply`; no afecta Compute, red,
storage, Vault ni recursos de aplicación.

### Costos

OCI Monitoring y Notifications tienen niveles gratuitos amplios, pero pueden
generar cargos al superar los límites de ingestión, consulta o entrega. Revisa el
consumo y los precios vigentes de la tenancy, especialmente para notificaciones
frecuentes, SMS o integraciones externas.

---

## IP pública reservada

Terraform crea una Reserved Public IP y la asocia a la interfaz de red de la instancia.

Esto permite que la dirección pública tenga un ciclo de vida independiente de la VM.

---

## Bootstrap automático

La configuración inicial del servidor se realiza mediante cloud-init.

Terraform envía un `user_data` a OCI Compute durante la creación de la instancia.

Durante el primer inicio se ejecuta automáticamente el proceso de bootstrap:

```text
Nueva VM
   │
   ▼
cloud-init
   │
   ├── instala Docker
   ├── instala Docker Compose
   ├── instala OCI CLI
   ├── habilita firewalld
   ├── configura puertos
   ├── crea /opt/apps
   ├── crea la red Docker "proxy"
   └── inicia Traefik
```

Esto permite crear una plataforma funcional sin tener que instalar manualmente cada componente mediante SSH.

---

## Docker

Cloud-init instala:

- Docker Engine
- Docker CLI
- containerd
- Docker Buildx
- Docker Compose Plugin

También habilita Docker automáticamente:

```bash
systemctl enable --now docker
```

y agrega el usuario `opc` al grupo Docker.

---

## Estructura del servidor

Durante el bootstrap se genera la siguiente estructura:

```text
/opt/apps/
│
├── proxy/
│   ├── docker-compose.yml
│   └── letsencrypt/
│       └── acme.json
│
├── shared/
│
└── apps/
```

La carpeta:

```text
/opt/apps/apps/
```

queda disponible para alojar futuras aplicaciones.

---

## Red Docker compartida

La infraestructura crea una red Docker externa llamada:

```text
proxy
```

Esta red permite conectar Traefik con las diferentes aplicaciones.

```text
Traefik
   │
   └── proxy
        │
        ├── aplicación A
        ├── aplicación B
        └── aplicación C
```

Las aplicaciones pueden permanecer aisladas entre sí mientras comparten el Reverse Proxy.

---

## Traefik

Traefik funciona como Reverse Proxy de la plataforma.

Sus responsabilidades principales son:

- recibir tráfico HTTP
- recibir tráfico HTTPS
- redireccionar HTTP hacia HTTPS
- detectar containers Docker
- enrutar tráfico hacia las aplicaciones
- gestionar certificados TLS
- integrarse con Let's Encrypt

Los puertos públicos utilizados son:

```text
80
443
```

Las aplicaciones no necesitan publicar directamente sus puertos al exterior.

---

## Let's Encrypt

Traefik utiliza Let's Encrypt para obtener certificados TLS automáticamente.

La infraestructura utiliza el desafío:

```text
HTTP-01
```

El correo utilizado para ACME se configura mediante:

```hcl
acme_email = "correo@example.com"
```

Los certificados se almacenan en:

```text
/opt/apps/proxy/letsencrypt/acme.json
```

---

## OCI Vault

Terraform crea un Vault para la plataforma.

El nombre se genera a partir del nombre del proyecto.

Ejemplo:

```text
mi-proyecto-vault
```

El Vault queda disponible para almacenar posteriormente:

- API Keys
- Tokens
- Contraseñas
- Credenciales
- Secretos de aplicaciones

Esta infraestructura no crea secretos específicos de una aplicación.

---

## OCI KMS

Terraform también crea una clave KMS utilizada para la gestión criptográfica del Vault.

La configuración utiliza:

```text
AES 256 bits
```

La clave queda desacoplada de las aplicaciones desplegadas posteriormente.

---

## IAM e Instance Principal

La infraestructura crea un Dynamic Group para la instancia OCI.

La VM puede identificarse frente a servicios OCI mediante Instance Principal.

El flujo es:

```text
OCI Compute
     │
     ▼
Instance Principal
     │
     ▼
Dynamic Group
     │
     ▼
IAM Policy
     │
     ▼
OCI Vault
```

Esto evita almacenar credenciales estáticas de OCI dentro del servidor.

---

## Política de secretos

La política IAM permite que la instancia lea Secret Bundles del compartment configurado.

Los secretos concretos se crean posteriormente y no forman parte de esta plantilla.

Esto mantiene separadas:

```text
Infraestructura
      │
      └── permisos y Vault

Aplicaciones
      │
      └── secretos específicos
```

---

## Estructura del proyecto

```text
docker-platform/
│
├── README.md
├── backup.tf
├── compute.tf
├── environment.tf
├── deployment.tf
├── iam.tf
├── locals.tf
├── logging.tf
├── network.tf
├── observability.tf
├── outputs.tf
├── providers.tf
├── registry.tf
├── security.tf
├── variables.tf
├── vault.tf
├── versions.tf
├── .terraform.lock.hcl
│
├── environments/
│   ├── dev/
│   │   ├── backend.oci.tfbackend.example
│   │   └── terraform.tfvars.example
│   ├── staging/
│   │   ├── backend.oci.tfbackend.example
│   │   └── terraform.tfvars.example
│   └── prod/
│       ├── backend.oci.tfbackend.example
│       └── terraform.tfvars.example
├── cloud-init/
│   ├── bootstrap.yaml.tftpl
│   ├── deploy-compose-app.py
│   └── install-ocir-helper.sh.tftpl
│
├── deployment/
│   ├── README.md
│   ├── app-config.example.json
│   ├── compose.example.yml
│   └── github-actions/
│       └── deploy.yml.example
│
└── proxy/
    └── docker-compose.yml.tftpl
```

---

## Variables principales

La infraestructura permite configurar:

```text
tenancy_ocid
compartment_ocid
compartment_name
environment_name
project_name
region
oci_auth
oci_config_file_profile
vcn_cidr
public_subnet_cidr
ssh_public_key_path
ssh_source_cidr
shape
ocpus
memory_in_gbs
boot_volume_size_in_gbs
image_ocid
acme_email
traefik_image
media_bucket_name
object_storage_access_type
object_storage_versioning
object_storage_lifecycle_enabled
object_storage_archive_after_days
object_storage_delete_previous_versions_after_days
object_storage_abort_multipart_uploads_after_days
backup_enabled
backup_frequency
backup_type
backup_retention_days
backup_hour_utc
backup_day_of_week
backup_day_of_month
logging_enabled
logging_log_group_name
logging_retention_days
logging_sources
registry_enabled
registry_repository_names
registry_visibility
registry_immutable
registry_freeform_tags
deployment_enabled
deployment_principals
monitoring_enabled
notification_topic_name
notification_protocol
notification_endpoint
cpu_alarm_threshold_percent
cpu_alarm_pending_duration_minutes
cpu_alarm_severity
```

---

## Entornos independientes

La plataforma utiliza un único código Terraform y tres configuraciones
independientes: `dev`, `staging` y `prod`. No usa Terraform Workspaces como
mecanismo principal y no existe un entorno por defecto. Cada comando que cargue
variables o backend debe indicar el entorno de forma explícita.

```text
environments/
├── dev/
│   ├── backend.oci.tfbackend.example
│   └── terraform.tfvars.example
├── staging/
│   ├── backend.oci.tfbackend.example
│   └── terraform.tfvars.example
└── prod/
    ├── backend.oci.tfbackend.example
    └── terraform.tfvars.example
```

Los tres backends pueden usar el bucket privado y dedicado de Terraform State,
pero deben usar claves distintas:

| Entorno | Remote state key |
| --- | --- |
| `dev` | `docker-platform/dev/terraform.tfstate` |
| `staging` | `docker-platform/staging/terraform.tfstate` |
| `prod` | `docker-platform/prod/terraform.tfstate` |

Compartir bucket no equivale a compartir state: la separación se realiza por
clave y por archivo de backend. Para mayor aislamiento administrativo, prod
puede usar otro bucket dedicado, conservando la misma clave relativa. Nunca uses
el bucket media ni copies un state entre entornos.

### Preparar un entorno

Elige el entorno antes de copiar archivos. Este ejemplo prepara dev:

```bash
cp environments/dev/terraform.tfvars.example \
  environments/dev/terraform.tfvars
cp environments/dev/backend.oci.tfbackend.example \
  environments/dev/backend.oci.tfbackend
```

Los archivos reales están ignorados por Git en cualquier subdirectorio. Revisa
que `environment_name`, compartment, CIDRs, nombres, capacidad y backend
correspondan al mismo entorno antes de inicializar.

DEV:

```bash
terraform init \
  -backend-config=environments/dev/backend.oci.tfbackend \
  -reconfigure
terraform plan \
  -var-file=environments/dev/terraform.tfvars
```

STAGING:

```bash
terraform init \
  -backend-config=environments/staging/backend.oci.tfbackend \
  -reconfigure
terraform plan \
  -var-file=environments/staging/terraform.tfvars
```

PROD:

```bash
terraform init \
  -backend-config=environments/prod/backend.oci.tfbackend \
  -reconfigure
terraform plan \
  -var-file=environments/prod/terraform.tfvars
```

`-reconfigure` es obligatorio al cambiar de entorno en el mismo checkout. Una
alternativa más segura es usar un checkout o worktree distinto por entorno. No
ejecutes prod desde un directorio que acaba de utilizar otro backend sin volver a
inicializarlo y comprobar la línea `key`.

### Controles por entorno

- DEV prioriza bajo costo. Monitoring, logging, backups y registry pueden estar
  desactivados; SSH público produce una advertencia visible.
- STAGING debe parecerse a prod. SSH público se bloquea y los controles
  operativos desactivados generan advertencias de Policy as Code.
- PROD bloquea SSH público y exige monitoring, logging, backups, registry privado
  e inmutable y Object Storage privado con versionado.

`environment_name` es obligatorio y no tiene valor por defecto. Terraform valida
los controles mínimos de prod antes de planificar. Policy as Code valida además
los ejemplos y la clave exacta del backend sin publicar sus valores.

### Workflows y producción

- `terraform-ci.yml` valida los tres ejemplos en pull requests sin acceder a OCI.
  Una ejecución manual exige elegir un entorno.
- `terraform-policy.yml` aplica el perfil correspondiente a dev, staging o prod.
  En pull requests ejecuta los tres perfiles; manualmente exige selección.
- `terraform-drift.yml` usa archivos root-owned separados en el runner bajo
  `/etc/terraform/oci/docker-platform/<environment>/`. Manualmente exige elegir
  entorno; el schedule recorre la matriz solo cuando
  `DRIFT_DETECTION_ENABLED == "true"`.

Configura en GitHub los Environments `infrastructure-dev`,
`infrastructure-staging` e `infrastructure-prod`. Para prod aplica required
reviewers, restringe las ramas autorizadas y limita el runner y su Instance
Principal. Las reglas de protección viven en GitHub y no se versionan en este
repositorio. Protege además la rama principal y exige Terraform CI y Policy as
Code como checks requeridos.

### Adoptar un state existente

No inicialices los tres backends contra el state actual. Primero identifica qué
entorno representa la infraestructura desplegada y detén cualquier ejecución
concurrente. Después crea únicamente los archivos reales de ese entorno y migra:

```bash
terraform init \
  -migrate-state \
  -backend-config=environments/ENTORNO/backend.oci.tfbackend
```

Confirma el origen y destino mostrados por Terraform y ejecuta un plan con el
`terraform.tfvars` del mismo entorno. Crear los otros backends produce states
vacíos para infraestructuras nuevas; no copies el state migrado. Cambiar
`project_name`, CIDRs, compartments o nombres durante esta adopción puede forzar
reemplazos y debe revisarse en una operación posterior y separada.

---

## Configuración

Crear el archivo local de variables:

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
```

Ejemplo:

```hcl
tenancy_ocid     = "ocid1.tenancy..."
compartment_ocid = "ocid1.compartment..."
compartment_name = "mi-compartment"

environment_name = "dev"
project_name     = "mi-proyecto-dev"

region                  = "sa-saopaulo-1"
oci_auth                = "InstancePrincipal"
oci_config_file_profile = "DEFAULT"

ocpus         = 2
memory_in_gbs = 12

vcn_cidr           = "10.20.0.0/16"
public_subnet_cidr = "10.20.1.0/24"

ssh_public_key_path = "~/.ssh/id_rsa.pub"

ssh_source_cidr = "0.0.0.0/0"

acme_email = "correo@example.com"

backup_enabled = false

logging_enabled = false

registry_enabled = false

registry_immutable = null

deployment_enabled = false

monitoring_enabled = false
```

El archivo:

```text
environments/<environment>/terraform.tfvars
```

no debe almacenarse en Git.

---

## Inicialización

Esta arquitectura utiliza el backend nativo de OCI, disponible desde Terraform
1.12.0. Primero crea el bucket dedicado mediante
[`../terraform-state`](../terraform-state/) y consulta sus outputs.

Crea la configuración local del backend:

```bash
cp environments/dev/backend.oci.tfbackend.example environments/dev/backend.oci.tfbackend
```

Reemplaza `bucket` y `namespace` con los outputs del bootstrap. Conserva la clave
exclusiva:

```hcl
key = "docker-platform/dev/terraform.tfstate"
```

`environments/<environment>/backend.oci.tfbackend` está ignorado por Git. No
agregues allí claves privadas, tokens ni contraseñas. Terraform carga el backend
antes que las variables, por lo que esta configuración no pertenece al
`terraform.tfvars` del entorno.

Inicializa Terraform:

```bash
terraform init -backend-config=environments/dev/backend.oci.tfbackend
```

---

## OCI Cloud Shell

Cloud Shell incluye Terraform y OCI CLI. Comprueba primero que la versión sea
1.12.0 o posterior:

```bash
terraform version
```

La autenticación preconfigurada de OCI CLI en Cloud Shell usa un token delegado.
Para que el provider y el backend nativo compartan una autenticación soportada,
crea un perfil temporal:

```bash
oci session authenticate --profile-name TERRAFORM
```

Configura `environments/dev/terraform.tfvars`:

```hcl
oci_auth                = "SecurityToken"
oci_config_file_profile = "TERRAFORM"
```

Y agrega localmente a `environments/dev/backend.oci.tfbackend`:

```hcl
auth                = "SecurityToken"
config_file_profile = "TERRAFORM"
```

No subas el perfil ni su token a Git. Si la sesión expira, renuévala antes de
ejecutar `plan` o `apply`.

---

## Formatear

```bash
terraform fmt -recursive
```

---

## Validar

```bash
terraform validate
```

---

## Revisar el plan

```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

Siempre se recomienda revisar el plan antes de ejecutar cambios sobre infraestructura real.

---

## Crear la infraestructura

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

Terraform solicitará confirmación antes de realizar los cambios.

---

## Consultar outputs

Después del despliegue:

```bash
terraform output
```

Entre los outputs disponibles se encuentran:

```text
server_id
server_public_ip
server_private_ip
vcn_id
subnet_id
vault_id
key_id
media_bucket_name
media_bucket_access_type
media_bucket_versioning
object_storage_lifecycle_policy_id
backup_enabled
boot_volume_id
boot_volume_backup_policy_id
boot_volume_backup_policy_assignment_id
logging_enabled
logging_status
log_group_id
logs_created
logging_agent_configuration_ids
registry_enabled
registry_status
registry_namespace
registry_repository_count
registry_repository_names
registry_repository_urls
monitoring_enabled
notification_topic_id
notification_subscription_id
notification_subscription_state
cpu_alarm_id
```

---

## Destruir la infraestructura

Cuando la infraestructura ya no sea necesaria:

```bash
terraform destroy
```

Se recomienda revisar cuidadosamente el plan de destrucción antes de confirmarlo.

---

## Despliegue de aplicaciones

Las aplicaciones, sus tests y sus Dockerfiles permanecen en repositorios
separados. Esta arquitectura aporta únicamente un contrato de deployment
restringido y deshabilitado por defecto:

```hcl
deployment_enabled = false
```

Al habilitarlo también deben habilitarse el registry y su inmutabilidad:

```hcl
registry_enabled   = true
registry_immutable = true
deployment_enabled = true
```

### Separación de pipelines

La CI de este repositorio ejecuta validación y plan de Terraform. Nunca debe
construir o desplegar aplicaciones.

Cada repositorio de aplicación mantiene su propio workflow para:

```text
test -> build -> security scan -> push SHA -> Run Command -> health check
```

El workflow de referencia está en
[`deployment/github-actions/deploy.yml.example`](deployment/github-actions/deploy.yml.example).
No usa `latest` y despliega siempre el SHA completo de `GITHUB_SHA`.

### Autenticación y mínimo privilegio

Terraform no crea usuarios, API keys, auth tokens, passwords ni membresías. La
autenticación queda desacoplada mediante principales IAM preexistentes:

```hcl
deployment_principals = {
  service-a = {
    principal_type   = "dynamic-group"
    principal_name   = "github-runner-service-a-dg"
    repository_names = ["platform/service-a"]
  }
}
```

Se recomienda un principal por aplicación o dominio de confianza. Cada policy
permite `REPOSITORY_READ` y `REPOSITORY_UPDATE` solamente sobre los nombres
indicados; no permite crear, borrar ni administrar otros repositorios. También
permite solicitar OCI Run Command en el compartment.

El ejemplo presupone un runner OCI dedicado, preferentemente efímero, con
Instance Principal, OCI CLI y `docker-credential-ocir`. Así no existen
credenciales OCI permanentes en GitHub. OCI Identity Domains soporta intercambio
de JWT externos por tokens temporales, pero GitHub OIDC hacia OCI/OCIR requiere
configuración de federación adicional y no se implementa aquí como integración
turnkey.

### Wrapper privilegiado

OCI Run Command ejecuta inicialmente como `ocarun`. La única elevación
permitida es:

```text
deploy-compose-app <app> <commit-sha>
```

El wrapper exige exactamente esos dos argumentos. El repositorio, Compose,
servicio, health check e imágenes auxiliares están definidos en archivos
`root:root` bajo `/etc/docker-platform/apps/<app>`. `ocarun` no pertenece al
grupo Docker y no puede escribir la configuración ni `/opt/apps/apps`.

Antes de cualquier pull o `compose up`, el wrapper normaliza y valida el Compose
contra un esquema cerrado. Rechaza campos desconocidos, symlinks, bind mounts,
`privileged`, Docker socket, namespaces del host, devices, `cap_add`, ports
publicados, builds y cualquier imagen no autorizada.

Después de validar, descarga `<repository>:<commit-sha>`, resuelve su digest y
vuelve a validar. Tanto `compose pull` como `compose up` reciben exclusivamente
`<repository>@sha256:...`. El rollback conserva el Compose y digest anteriores.
Los logs incluyen aplicación, SHA, digest y etapa, pero no configuración,
variables de entorno, URLs ni salidas que puedan contener secretos.

Consulta [`deployment/README.md`](deployment/README.md) para registrar una
aplicación y preparar manualmente una VM existente.

### Impacto sobre Compute

El cambio de cloud-init solo prepara instancias nuevas. `compute.tf` continúa
ignorando cambios posteriores en `metadata.user_data`, por lo que habilitar esta
capa no modifica ni reemplaza la instancia existente. La instalación inicial
del wrapper en una VM ya creada es una operación administrativa explícita.

### Disponibilidad y riesgo residual

Descargar antes de ejecutar `compose up` reduce el intervalo de recreación y un
health check fallido activa rollback. Docker Compose sobre una sola VM no puede
garantizar cero downtime; blue/green real requiere diseño específico de la
aplicación o más capacidad.

Una imagen maliciosa todavía puede comprometer todos los recursos que el Compose
autorizado exponga al contenedor, incluidos named volumes, redes, variables y
servicios alcanzables. También puede explotar vulnerabilidades del kernel o del
runtime. Esta arquitectura reduce los privilegios del pipeline, pero no
convierte un contenedor malicioso en seguro.

Run Command no informa al wrapper qué principal originó el comando. Un principal
compartido puede solicitar el redeployment de cualquier nombre conocido en la
allowlist local, aunque solo pueda publicar en sus repositorios autorizados.
Usa GitHub Environments con aprobación, branch protection y principales
separados; para aislamiento completo se requieren hosts o un broker por dominio
de confianza.

### Costos

La capa no crea Compute, buckets ni servicios de build. Puede generar costos por
el runner elegido, minutos de GitHub Actions, almacenamiento y transferencia de
imágenes OCIR, y escaneo de imágenes. OCI Run Command y las policies IAM no
añaden almacenamiento por sí mismos. La acumulación de imágenes inmutables debe
gestionarse mediante una política operativa de limpieza revisada por separado.

---

## Gestión de secretos

Los valores sensibles no deben almacenarse:

- en Git
- en `docker-compose.yml`
- en Terraform
- dentro de las imágenes Docker

OCI Vault queda preparado para almacenar estos secretos.

Las aplicaciones pueden recuperarlos utilizando OCI CLI e Instance Principal.

---

## Archivos que no deben subirse a Git

El repositorio excluye:

```text
terraform.tfvars
*.tfbackend
*.tfstate
*.tfstate.*
*.tfplan
.terraform/
.env
*.pem
*.key
```

Los archivos `environments/*/terraform.tfvars.example` y
`environments/*/backend.oci.tfbackend.example` sí forman parte del repositorio
porque documentan la configuración necesaria sin contener valores reales.

---

## Terraform State

El state se almacena en un bucket privado y versionado separado del bucket
`media`. El backend nativo de OCI añade bloqueo mediante un objeto temporal, por
lo que evita operaciones concurrentes sobre la misma clave.

Cada arquitectura debe usar una clave distinta:

```text
docker-platform/dev/terraform.tfstate
docker-platform/staging/terraform.tfstate
docker-platform/prod/terraform.tfstate
```

La identidad que ejecuta Terraform necesita permisos `OBJECT_INSPECT`,
`OBJECT_CREATE`, `OBJECT_READ` y `OBJECT_DELETE` sobre el bucket de state. No
concedas esos permisos al Dynamic Group del servidor Docker.

### Migrar desde state local

1. Detén ejecuciones concurrentes de Terraform.
2. Crea el bucket con `oci/terraform-state` y configura los permisos IAM.
3. Realiza una copia segura de `terraform.tfstate` fuera del repositorio.
4. Elige un único entorno y crea su archivo
   `environments/ENTORNO/backend.oci.tfbackend` desde el ejemplo. Verifica
   especialmente `bucket`, `namespace`, `region` y `key`.
5. Ejecuta:

```bash
terraform init -migrate-state -backend-config=environments/ENTORNO/backend.oci.tfbackend
```

Terraform solicitará confirmación antes de copiar el state local. Después de la
migración:

```bash
terraform state list
terraform plan -var-file=environments/ENTORNO/terraform.tfvars
```

El plan esperado no debe proponer cambios por el solo hecho de mover el state.
Conserva temporalmente la copia local hasta verificar el objeto remoto y su
versionado. Los archivos `*.tfstate*` continúan ignorados por Git.

---

## Detección automática de drift

El workflow [`.github/workflows/terraform-drift.yml`](../../.github/workflows/terraform-drift.yml)
compara periódicamente la configuración Terraform versionada con la
infraestructura que OCI devuelve al refrescar el state remoto. Se puede ejecutar:

- manualmente desde **Actions > Terraform Drift Detection > Run workflow**, seleccionando obligatoriamente dev, staging o prod;
- automáticamente cada lunes a las `06:17 UTC`, solamente cuando la variable de
  repositorio `DRIFT_DETECTION_ENABLED` tiene el valor exacto `true`.

La ejecución programada está desactivada por defecto. Configúrala desde
**Settings > Secrets and variables > Actions > Variables**:

```text
DRIFT_DETECTION_ENABLED = true
```

Si la variable no existe, contiene `false` o cualquier valor distinto de `true`,
GitHub crea la ejecución programada pero omite el job y no ejecuta Terraform. La
comparación distingue mayúsculas y minúsculas. `workflow_dispatch` no depende de
esta variable: una ejecución manual siempre puede iniciar el job aunque la
detección automática esté desactivada.

El control ejecuta `terraform init`, `terraform validate` y:

```bash
terraform plan -detailed-exitcode
```

Un plan normal puede detectar tanto cambios realizados fuera de Terraform como
código versionado que todavía no fue aplicado. Por eso, el exit code `2` exige
revisión humana antes de decidir si debe corregirse OCI o actualizarse el código.

### Runner y autenticación

La ejecución programada usa un runner OCI self-hosted dedicado y autenticado con
Instance Principal. No utiliza API keys, auth tokens ni claves privadas de OCI en
GitHub. Configura la variable de repositorio `OCI_TERRAFORM_RUNNER_LABEL` con la
etiqueta asignada a ese runner; si no existe, el workflow busca la etiqueta
`oci-terraform`. Mantén actualizado GitHub Actions Runner para que soporte el
runtime Node.js 24 utilizado por `hashicorp/setup-terraform` v4.

El runner debe mantener fuera del checkout estos archivos protegidos:

```text
/etc/terraform/oci/docker-platform/<environment>/backend.oci.tfbackend
/etc/terraform/oci/docker-platform/<environment>/terraform.tfvars
```

Ambos deben ser archivos regulares, no symlinks, y no pueden ser escribibles por
grupo ni por otros usuarios. El primero conserva la configuración del backend
remoto dedicado e incluye:

```hcl
auth = "InstancePrincipal"
```

El segundo contiene los valores reales de la arquitectura y configura:

```hcl
environment_name = "dev|staging|prod"
oci_auth         = "InstancePrincipal"
```

El `ssh_public_key_path` utilizado por Terraform debe apuntar a una clave pública
disponible para el runner. Estos archivos pueden contener datos operativos y no
deben copiarse al repositorio, a artifacts ni al resumen del workflow.

No se requieren GitHub Actions secrets en este modo. La identidad del runner
necesita exclusivamente:

- acceso al bucket dedicado de state para leer el objeto y gestionar su lock;
- permisos de lectura sobre los tipos de recursos OCI administrados por esta
  arquitectura;
- ningún permiso para crear, actualizar o eliminar recursos durante este control.

No reutilices el Dynamic Group de la VM Docker. Mantén un principal separado para
el runner de Terraform y limita su pertenencia a una instancia dedicada siempre
que sea posible. Protege también la rama por defecto: Terraform puede evaluar
data sources y código versionado durante un plan.

### Interpretar el resultado

| Exit code | Resultado | Estado del workflow |
| --- | --- | --- |
| `0` | No hay diferencias | Correcto |
| `1` | Error de Terraform, autenticación, backend o provider | Fallo |
| `2` | Existen cambios pendientes | Fallo con advertencia de drift |

El resumen de GitHub Actions incluye únicamente la arquitectura, el commit, la
fecha, el exit code y la clasificación. El output completo del plan se guarda
temporalmente con permisos restrictivos y se elimina al terminar; no se publica
el state, un archivo de plan, variables ni artifacts.

### Responder ante drift

1. No ejecutes `apply` desde el workflow ni desde un entorno no controlado.
2. Comprueba si hubo un cambio manual autorizado o código fusionado aún no
   aplicado.
3. Desde un entorno protegido, renueva la autenticación y ejecuta nuevamente
   `terraform plan` contra el mismo backend y las mismas variables.
4. Revisa reemplazos, destrucciones, IAM, Compute, buckets, Vault y KMS.
5. Si OCI fue modificado por error, corrígelo mediante un cambio Terraform
   revisado. Si el cambio externo es la nueva intención, actualiza o importa el
   código/state de forma explícita.
6. Conserva evidencia de la decisión y vuelve a ejecutar el workflow hasta
   obtener exit code `0`.

El workflow nunca ejecuta `terraform apply` y no crea Issues automáticamente. Si
se incorpora esa capacidad en el futuro, debe evitar duplicados, usar permisos
`issues: write` únicamente y no incluir el contenido del plan.

La implementación usa una matriz explícita para `dev`, `staging` y `prod`. Cada
entrada tiene backend, variables, GitHub Environment y grupo de concurrencia
independientes. Para incorporar otra arquitectura, agrega sus entradas sin
reutilizar rutas protegidas ni claves de state.

---

## Policy as Code

El workflow `.github/workflows/terraform-policy.yml` analiza los cambios de
`oci/docker-platform` en cada pull request y también admite ejecución manual con
`workflow_dispatch`. Usa Checkov fijado a una versión concreta y políticas
locales versionadas en `.github/policies`.

Este control es estático: no consulta OCI, no inicializa el backend y no lee
`terraform.tfvars`, planes ni state. Por ese motivo no necesita credenciales ni
secretos de GitHub. Sus permisos se limitan a `contents: read` y nunca ejecuta
`terraform apply`.

El análisis se divide en dos niveles:

| Nivel | Comportamiento | Controles principales |
| --- | --- | --- |
| Bloqueo | Falla el job y debe corregirse o exceptuarse | SSH público, buckets públicos, IAM administrativo sin restricciones, ingress total, secretos hardcodeados e imágenes `latest` o sin tag |
| Advertencia | Aparece en el resumen sin bloquear | Recursos principales sin tags, egress amplio, grants `manage` que requieren revisión y el resto del baseline OCI de Checkov |

Checkov aporta de forma nativa, entre otros, `CKV_OCI_1` para claves privadas en
el provider y `CKV_OCI_10` para Object Storage público. El scanner de secretos
de Checkov se ejecuta por separado para que una credencial detectada siempre sea
un error.

Los checks nativos de SSH `CKV_OCI_19` y `CKV_OCI_22` se excluyen de la
decisión: el primero produce falsos positivos en security lists sin ingress y el
segundo duplicaría el control local. La política personalizada verifica las reglas
reales de NSG y security lists, por lo que SSH público continúa siendo bloqueante.

Las políticas personalizadas completan los casos que el baseline no interpreta
de forma suficiente:

- `CKV2_IAC_OCI_1`: bloquea `any-user`, `manage/use all-resources` y grants
  `manage` a nivel tenancy sin condición.
- `CKV2_IAC_OCI_2`: bloquea SSH e ingress público para todos los protocolos.
- `CKV2_IAC_OCI_101`: advierte cuando un recurso OCI principal y taggeable no
  define `freeform_tags` o `defined_tags`.
- `CKV2_IAC_OCI_102`: advierte sobre egress de todos los protocolos a Internet.
- `CKV2_IAC_OCI_103`: advierte sobre grants `manage` de compartment sin una
  condición adicional.
- `IAC_DOCKER_001`: bloquea imágenes literales con `:latest` o sin tag en
  Terraform y plantillas Compose. Las imágenes dinámicas siguen sujetas a las
  validaciones del wrapper de deployment.
- `IAC_ENV_001`: bloquea archivos o claves de state que no coincidan con el
  entorno seleccionado.
- `IAC_ENV_002`: bloquea SSH público en staging y prod.
- `IAC_ENV_003`: bloquea controles obligatorios desactivados en prod.
- `IAC_ENV_101`: advierte si staging se aleja de los controles de prod.
- `IAC_ENV_102`: reporta SSH público como warning únicamente en dev.

El resumen de GitHub Actions muestra únicamente regla, descripción y ubicación.
No publica líneas de código, valores, coincidencias de secretos ni resultados
crudos de Checkov.

### Excepciones documentadas

Las excepciones se registran en `.github/policies/exceptions.json` y deben estar
acotadas a una regla, ruta y, cuando corresponda, recurso exactos. También deben
incluir `owner`, una justificación de al menos 20 caracteres y `expires_on` en
formato `YYYY-MM-DD`. Las excepciones vencidas o mal formadas bloquean el PR; las
que ya no coinciden con un finding generan una advertencia para poder retirarlas.

Ejemplo:

```json
{
  "rule_id": "CKV2_IAC_OCI_2",
  "path": "oci/docker-platform/security.tf",
  "resource": "oci_core_network_security_group_security_rule.ssh",
  "owner": "platform",
  "reason": "Excepcion temporal asociada a un riesgo aceptado y documentado.",
  "expires_on": "2027-03-31"
}
```

La plantilla conserva una excepción temporal para el valor histórico
`ssh_source_cidr = "0.0.0.0/0"`. No desactiva la regla globalmente: otro recurso
SSH público seguirá bloqueando el PR. En despliegues reales configura un CIDR
administrativo restringido y elimina la excepción.

Los falsos positivos más probables provienen de valores calculados que Checkov
no puede resolver sin un plan, recursos OCI que no admiten tags, ingress público
80/443 requerido por Traefik y permisos `manage` cuyo alcance real está limitado
por condiciones interpoladas. No agregues excepciones silenciosas: revisa el
resultado, limita el alcance y documenta la decisión con vencimiento.

Para ejecutar localmente el mismo control:

```bash
python3 -m pip install checkov==3.3.8
python3 .github/policies/run_policy_checks.py \
  --directory oci/docker-platform \
  --exceptions .github/policies/exceptions.json \
  --environment dev
```

Al incorporar otra arquitectura, agrega su ruta al filtro del workflow y crea un
job o matriz que invoque el mismo ejecutor con excepciones específicas. Evita
convertir excepciones de una arquitectura en exclusiones globales.

---

## Validación de la plantilla

La configuración fue validada utilizando:

```bash
terraform init -reconfigure \
  -backend-config=environments/ENTORNO/backend.oci.tfbackend
terraform validate
terraform plan -var-file=environments/ENTORNO/terraform.tfvars
```

Con `monitoring_enabled = false`, la cantidad base histórica para una
infraestructura completamente nueva fue:

```text
Plan: 16 to add, 0 to change, 0 to destroy.
```

Esto permitió comprobar que la plantilla representa una infraestructura independiente y no intenta modificar otros entornos existentes.

Al habilitar la observabilidad se agregan tres recursos opcionales: topic,
suscripción y alarma. Al habilitar backups se agregan una política y su
asignación; lifecycle agrega una política sobre el bucket existente. Logging
agrega un Log Group, un log y una configuración de agente por fuente, además de
una política IAM de ingestión. Antes de aplicar, verifica que el plan no
reemplace ni destruya recursos existentes. Registry agrega un recurso por nombre
configurado y una policy IAM de solo lectura. El cambio de cloud-init queda
ignorado para instancias existentes, por lo que no reemplaza Compute.
Deployment agrega una policy para la instancia y una por principal configurado;
no crea aplicaciones, credenciales ni buckets. La inmutabilidad de OCIR es una
actualización in-place que solo se exige cuando `deployment_enabled` es `true`.

---

## Origen de la arquitectura

Esta IaC surgió a partir de una infraestructura real desplegada inicialmente de forma manual en Oracle Cloud Infrastructure.

El proceso de evolución fue:

```text
Infraestructura manual
        │
        ▼
Validación del entorno
        │
        ▼
Importación a Terraform
        │
        ▼
Estado sin drift
        │
        ▼
Automatización con cloud-init
        │
        ▼
Generalización
        │
        ▼
Plantilla reutilizable
```

Durante el proceso se trabajó con:

- OCI Compute
- VCN
- Subnets
- Internet Gateway
- Route Tables
- NSG
- Reserved Public IP
- Docker
- Traefik
- HTTPS
- OCI Vault
- KMS
- Dynamic Groups
- IAM Policies
- Instance Principal
- Terraform
- cloud-init

La aplicación utilizada durante el despliegue original fue eliminada conceptualmente de la plantilla final.

El resultado es una infraestructura desacoplada que puede servir como base para diferentes proyectos.

---

## Estado

**Estado actual: plantilla validada mediante Terraform Plan.**

```text
terraform init      ✅
terraform validate  ✅
terraform plan      ✅
0 cambios           ✅
0 destrucciones     ✅
```

La prueba completa de creación y destrucción de una infraestructura descartable puede realizarse posteriormente como validación end-to-end.

---

## OCI Object Storage

La plataforma incluye un bucket de OCI Object Storage preparado para almacenar archivos asociados a las aplicaciones desplegadas.

Puede utilizarse para:

- imágenes
- documentos
- archivos multimedia
- logos
- contenido institucional
- archivos subidos por usuarios

Por defecto el bucket se crea como privado:

```hcl
object_storage_access_type = "NoPublicAccess"
```

También puede configurarse:

```hcl
object_storage_access_type = "ObjectReadWithoutList"
```

para permitir acceso público a objetos individuales sin permitir el listado público del contenido del bucket.

El nombre se genera automáticamente a partir de:

```hcl
project_name
```

Por ejemplo:

```text
project_name = "instituto"

instituto-media
```

También puede definirse manualmente:

```hcl
media_bucket_name = "instituto-archivos"
```

### Acceso desde las aplicaciones

La instancia OCI utiliza Instance Principal para acceder al bucket.

```text
Aplicación
    │
    ▼
OCI Compute
    │
    ▼
Instance Principal
    │
    ▼
Dynamic Group
    │
    ▼
IAM Policy
    │
    ▼
Object Storage
```

Por este motivo no es necesario almacenar credenciales OCI dentro de los contenedores.

El backend puede utilizar OCI SDK u OCI CLI para subir, consultar y eliminar objetos.
