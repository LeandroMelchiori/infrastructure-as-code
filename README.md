# Infrastructure as Code

Repositorio personal de arquitecturas e infraestructura como código.

El objetivo de este repositorio es documentar, versionar y reutilizar diferentes arquitecturas Cloud mediante herramientas como Terraform, Docker, cloud-init, Traefik, Vault e IAM.

Cada carpeta representa una infraestructura independiente y contiene su propia documentación, variables de ejemplo, decisiones de arquitectura e instrucciones de despliegue.

## Arquitecturas de referencia

- [Plataforma OCI de una VM para múltiples aplicaciones](./oci/reference-architectures/single-vm-multi-app/): composición reutilizable de bootstrap, state remoto, Docker Platform y buckets de aplicaciones sin duplicar Terraform.

## Casos prácticos

- [Plataforma OCI de desarrollo para NuevaMente](./oci/case-studies/nuevamente-dev-oci.md): arquitectura desplegada, proceso de autenticación, ejecución de Terraform, controles de seguridad y guía para explicar la solución.

## Infraestructuras

| Proveedor | Infraestructura | Descripción | Estado |
|---|---|---|---|
| OCI | [Platform Bootstrap](./oci/platform-bootstrap/) | Compartment de plataforma y bucket privado para Terraform State | Desplegada en dev |
| OCI | [Terraform State](./oci/terraform-state/) | Bucket privado y versionado para backends remotos de Terraform | Disponible |
| OCI | [Application Storage](./oci/application-storage/) | Bucket privado y policy IAM minima para documentos de aplicaciones | Preparada |
| OCI | [Docker Platform](./oci/docker-platform/) | Plataforma Docker reutilizable con networking, IAM, Vault, Traefik y bootstrap automatizado | Desplegada en dev |
| OCI | Kubernetes Platform | Plataforma basada en Kubernetes | Próximamente |
| AWS | Container Platform | Arquitectura de contenedores en AWS | Próximamente |

## Tecnologías

- Terraform
- Oracle Cloud Infrastructure
- Docker
- Docker Compose
- Traefik
- cloud-init
- OCI Vault
- OCI KMS
- IAM
- Linux
- Networking
- GitHub Actions

## Organización del repositorio

```text
infrastructure-as-code/
│
├── README.md
├── .gitignore
│
├── oci/
│   ├── reference-architectures/
│   │   ├── README.md
│   │   └── single-vm-multi-app/
│   │       └── README.md
│   │
│   ├── case-studies/
│   │   └── nuevamente-dev-oci.md
│   │
│   ├── platform-bootstrap/
│   │   ├── README.md
│   │   ├── *.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── terraform-state/
│   │   ├── README.md
│   │   ├── *.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── application-storage/
│   │   ├── README.md
│   │   └── *.tf
│   │
│   └── docker-platform/
│       ├── README.md
│       ├── *.tf
│       ├── environments/
│       │   ├── dev/
│       │   ├── staging/
│       │   └── prod/
│       ├── cloud-init/
│       ├── deployment/
│       └── proxy/
│
├── aws/
│   └── ...
│
└── azure/
    └── ...
```

## Resolución de restricciones para agentes

El repositorio incluye un resolver determinista en `tools/resolve_architecture.py` para que agentes como Nanami conviertan requisitos de alto nivel en inputs concretos de infraestructura sin depender de la memoria del LLM.

Ejemplo Always Free:

```bash
python tools/resolve_architecture.py \
  --architecture oci-single-vm-multi-app \
  --profile always-free \
  --ocpus 1 \
  --memory-gb 6 \
  --json
```

Los perfiles de restricciones viven en `policies/`. Un perfil válido limita recursos y genera inputs Terraform, pero no autoriza `terraform apply`; la elegibilidad de la cuenta, región, capacidad y el plan deben revisarse antes del despliegue.

## Terraform State

Cada arquitectura Terraform mantiene su propio state. `oci/docker-platform` usa
una configuración común con backends y claves independientes para `dev`,
`staging` y `prod`; no usa Workspaces como mecanismo principal. El bucket de
state se crea por separado y nunca se reutiliza como bucket de archivos de
aplicaciones. Puede crearse con
[`oci/terraform-state`](./oci/terraform-state/) cuando el compartment ya existe,
o con [`oci/platform-bootstrap`](./oci/platform-bootstrap/) cuando tambien debe
crearse el compartment.

Cuando el compartment de plataforma aun no existe, `oci/platform-bootstrap`
puede crear en una sola etapa bootstrap tanto el compartment como el bucket de
state. Al igual que `oci/terraform-state`, conserva state local deliberadamente.

La configuración del backend y las credenciales son locales. Los archivos
`*.tfbackend`, `terraform.tfvars`, `.terraform/` y `*.tfstate*` están excluidos de
Git; el repositorio solo contiene ejemplos sin secretos.

## Ownership de Object Storage

Cada bucket tiene un único root module propietario y un único state:

| Propósito | Root module propietario | State |
|---|---|---|
| Terraform State junto con un compartment nuevo | `oci/platform-bootstrap` | Local y protegido fuera de Git |
| Terraform State dentro de un compartment existente | `oci/terraform-state` | Local y protegido fuera de Git |
| Archivos genéricos de la plataforma Docker | `oci/docker-platform` | Backend remoto independiente por entorno |
| Documentos de una aplicación | `oci/application-storage` | Backend remoto propio |

`oci/platform-bootstrap` y `oci/terraform-state` son alternativas para el
bootstrap del state; nunca deben administrar el mismo bucket. Un bucket creado
por `oci/application-storage` puede concederse a Compute mediante
`external_object_storage_buckets`, pero permanece fuera del state de
`oci/docker-platform`.
