# OCI Docker Platform

Plantilla reutilizable de Infrastructure as Code para desplegar una plataforma Docker sobre Oracle Cloud Infrastructure.

La infraestructura está diseñada para ser independiente de las aplicaciones. Su objetivo es crear una base Cloud preparada para alojar distintos proyectos containerizados.

---

## Objetivo

Esta arquitectura permite ejecutar:

```bash
terraform init -backend-config=backend.oci.tfbackend
terraform plan
terraform apply
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
- OCI Monitoring
- OCI Notifications
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

El endpoint se define únicamente en `terraform.tfvars`, que está ignorado por
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
├── backend.oci.tfbackend.example
├── compute.tf
├── iam.tf
├── locals.tf
├── network.tf
├── observability.tf
├── outputs.tf
├── providers.tf
├── security.tf
├── variables.tf
├── vault.tf
├── versions.tf
├── terraform.tfvars.example
├── .terraform.lock.hcl
│
├── cloud-init/
│   └── bootstrap.yaml.tftpl
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
monitoring_enabled
notification_topic_name
notification_protocol
notification_endpoint
cpu_alarm_threshold_percent
cpu_alarm_pending_duration_minutes
cpu_alarm_severity
```

---

## Configuración

Crear el archivo local de variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Ejemplo:

```hcl
tenancy_ocid     = "ocid1.tenancy..."
compartment_ocid = "ocid1.compartment..."
compartment_name = "mi-compartment"

project_name = "mi-proyecto"

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

monitoring_enabled = false
```

El archivo:

```text
terraform.tfvars
```

no debe almacenarse en Git.

---

## Inicialización

Esta arquitectura utiliza el backend nativo de OCI, disponible desde Terraform
1.12.0. Primero crea el bucket dedicado mediante
[`../terraform-state`](../terraform-state/) y consulta sus outputs.

Crea la configuración local del backend:

```bash
cp backend.oci.tfbackend.example backend.oci.tfbackend
```

Reemplaza `bucket` y `namespace` con los outputs del bootstrap. Conserva la clave
exclusiva:

```hcl
key = "docker-platform/terraform.tfstate"
```

`backend.oci.tfbackend` está ignorado por Git. No agregues allí claves privadas,
tokens ni contraseñas. Terraform carga el backend antes que las variables, por lo
que esta configuración no pertenece a `terraform.tfvars`.

Inicializa Terraform:

```bash
terraform init -backend-config=backend.oci.tfbackend
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

Configura `terraform.tfvars`:

```hcl
oci_auth                = "SecurityToken"
oci_config_file_profile = "TERRAFORM"
```

Y agrega localmente a `backend.oci.tfbackend`:

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
terraform plan
```

Siempre se recomienda revisar el plan antes de ejecutar cambios sobre infraestructura real.

---

## Crear la infraestructura

```bash
terraform apply
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

Las aplicaciones se mantienen fuera de esta plantilla.

Una aplicación que quiera utilizar Traefik debe conectarse a la red externa:

```yaml
networks:
  proxy:
    external: true
```

Ejemplo de configuración mediante labels:

```yaml
services:
  app:
    image: mi-aplicacion

    networks:
      - proxy

    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls=true"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"

networks:
  proxy:
    external: true
```

De esta manera:

```text
Internet
   │
   ▼
Traefik
   │
   ▼
Aplicación
```

sin publicar directamente el puerto interno de la aplicación.

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

El archivo:

```text
terraform.tfvars.example
```

sí forma parte del repositorio porque documenta la configuración necesaria.

---

## Terraform State

El state se almacena en un bucket privado y versionado separado del bucket
`media`. El backend nativo de OCI añade bloqueo mediante un objeto temporal, por
lo que evita operaciones concurrentes sobre la misma clave.

Cada arquitectura debe usar una clave distinta:

```text
docker-platform/terraform.tfstate
otra-arquitectura/terraform.tfstate
```

La identidad que ejecuta Terraform necesita permisos `OBJECT_INSPECT`,
`OBJECT_CREATE`, `OBJECT_READ` y `OBJECT_DELETE` sobre el bucket de state. No
concedas esos permisos al Dynamic Group del servidor Docker.

### Migrar desde state local

1. Detén ejecuciones concurrentes de Terraform.
2. Crea el bucket con `oci/terraform-state` y configura los permisos IAM.
3. Realiza una copia segura de `terraform.tfstate` fuera del repositorio.
4. Crea `backend.oci.tfbackend` desde el ejemplo y verifica especialmente
   `bucket`, `namespace`, `region` y `key`.
5. Ejecuta:

```bash
terraform init -migrate-state -backend-config=backend.oci.tfbackend
```

Terraform solicitará confirmación antes de copiar el state local. Después de la
migración:

```bash
terraform state list
terraform plan
```

El plan esperado no debe proponer cambios por el solo hecho de mover el state.
Conserva temporalmente la copia local hasta verificar el objeto remoto y su
versionado. Los archivos `*.tfstate*` continúan ignorados por Git.

---

## Validación de la plantilla

La configuración fue validada utilizando:

```bash
terraform init
terraform validate
terraform plan
```

Con `monitoring_enabled = false`, la cantidad base histórica para una
infraestructura completamente nueva fue:

```text
Plan: 16 to add, 0 to change, 0 to destroy.
```

Esto permitió comprobar que la plantilla representa una infraestructura independiente y no intenta modificar otros entornos existentes.

Al habilitar la observabilidad se agregan tres recursos opcionales: topic,
suscripción y alarma. Al habilitar backups se agregan una política y su
asignación; lifecycle agrega una política sobre el bucket existente. Antes de
aplicar, verifica que el plan no reemplace ni destruya recursos existentes.

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
