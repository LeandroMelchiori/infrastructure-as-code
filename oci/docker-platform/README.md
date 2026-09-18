# OCI Docker Platform

Plantilla reutilizable de Infrastructure as Code para desplegar una plataforma Docker sobre Oracle Cloud Infrastructure.

La infraestructura está diseñada para ser independiente de las aplicaciones. Su objetivo es crear una base Cloud preparada para alojar distintos proyectos containerizados.

---

## Objetivo

Esta arquitectura permite ejecutar:

```bash
terraform init
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
├── compute.tf
├── iam.tf
├── locals.tf
├── network.tf
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

region   = "sa-saopaulo-1"
oci_auth = "InstancePrincipal"

ocpus         = 2
memory_in_gbs = 12

vcn_cidr           = "10.20.0.0/16"
public_subnet_cidr = "10.20.1.0/24"

ssh_public_key_path = "~/.ssh/id_rsa.pub"

ssh_source_cidr = "0.0.0.0/0"

acme_email = "correo@example.com"
```

El archivo:

```text
terraform.tfvars
```

no debe almacenarse en Git.

---

## Inicialización

Inicializar Terraform:

```bash
terraform init
```

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

Actualmente la plantilla permite trabajar con Terraform State local.

Para entornos colaborativos o productivos se recomienda evolucionar hacia un backend remoto con:

- almacenamiento remoto
- cifrado
- versionado
- control de acceso
- bloqueo de estado

---

## Validación de la plantilla

La configuración fue validada utilizando:

```bash
terraform init
terraform validate
terraform plan
```

El plan generado para una infraestructura completamente nueva fue:

```text
Plan: 16 to add, 0 to change, 0 to destroy.
```

Esto permitió comprobar que la plantilla representa una infraestructura independiente y no intenta modificar otros entornos existentes.

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
