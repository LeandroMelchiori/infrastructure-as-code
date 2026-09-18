# Infrastructure as Code

Repositorio personal de arquitecturas e infraestructura como código.

El objetivo de este repositorio es documentar, versionar y reutilizar diferentes arquitecturas Cloud mediante herramientas como Terraform, Docker, cloud-init, Traefik, Vault e IAM.

Cada carpeta representa una infraestructura independiente y contiene su propia documentación, variables de ejemplo, decisiones de arquitectura e instrucciones de despliegue.

## Infraestructuras

| Proveedor | Infraestructura | Descripción | Estado |
|---|---|---|---|
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
│   └── docker-platform/
│       ├── README.md
│       ├── *.tf
│       ├── terraform.tfvars.example
│       ├── cloud-init/
│       └── proxy/
│
├── aws/
│   └── ...
│
└── azure/
    └── ...
