# Infrastructure as Code

Repositorio personal de arquitecturas e infraestructura como código.

El objetivo de este repositorio es documentar, versionar y reutilizar diferentes arquitecturas Cloud mediante herramientas como Terraform, Docker, cloud-init, Traefik, Vault e IAM.

Cada carpeta representa una infraestructura independiente y contiene su propia documentación, variables de ejemplo, decisiones de arquitectura e instrucciones de despliegue.

## Infraestructuras

| Proveedor | Infraestructura | Descripción | Estado |
|---|---|---|---|
| OCI | [Terraform State](./oci/terraform-state/) | Bucket privado y versionado para backends remotos de Terraform | Disponible |
| OCI | [Docker Platform](./oci/docker-platform/) | Plataforma Docker reutilizable con networking, IAM, Vault, Traefik y bootstrap automatizado | Validada |
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
│   ├── terraform-state/
│   │   ├── README.md
│   │   ├── *.tf
│   │   └── terraform.tfvars.example
│   │
│   └── docker-platform/
│       ├── README.md
│       ├── *.tf
│       ├── backend.oci.tfbackend.example
│       ├── terraform.tfvars.example
│       ├── cloud-init/
│       └── proxy/
│
├── aws/
│   └── ...
│
└── azure/
    └── ...
```

## Terraform State

Cada arquitectura Terraform mantiene su propio state y utiliza una clave de objeto
exclusiva. El bucket de state se crea por separado mediante
[`oci/terraform-state`](./oci/terraform-state/) y nunca se reutiliza como bucket de
archivos de aplicaciones.

La configuración del backend y las credenciales son locales. Los archivos
`*.tfbackend`, `terraform.tfvars`, `.terraform/` y `*.tfstate*` están excluidos de
Git; el repositorio solo contiene ejemplos sin secretos.
