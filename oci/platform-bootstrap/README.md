# OCI Application Platform Bootstrap

Bootstrap independiente para crear mediante Terraform:

- un compartment dedicado a una plataforma compartida de aplicaciones;
- un bucket privado y versionado exclusivo para Terraform State.

No crea Compute, networking, aplicaciones ni buckets de contenido. Tampoco
adopta compartments o buckets existentes.

## Por que usa state local

El backend remoto debe existir antes de inicializar las configuraciones que lo
consumen. Este bootstrap crea el bucket, por lo que conserva deliberadamente su
propio state local.

El archivo `terraform.tfstate` es sensible y esta excluido de Git. Respaldalo en
una ubicacion segura que no dependa del mismo bucket administrado por este stack.

## Recursos

- `oci_identity_compartment.platform`;
- `oci_objectstorage_bucket.terraform_state`;
- consulta del namespace de Object Storage.

El compartment y el bucket usan `prevent_destroy`. El bucket tiene acceso
privado, tier Standard, versionado habilitado y eventos de objetos desactivados.

## Permisos previos

La identidad que ejecute Terraform necesita permisos para:

- crear y leer compartments bajo el padre elegido;
- inspeccionar el namespace de Object Storage;
- crear y administrar el bucket de state dentro del nuevo compartment.

El bootstrap no crea grupos, usuarios, API keys ni policies IAM amplias.

## Configuracion en OCI Cloud Shell

```bash
cd oci/platform-bootstrap
cp terraform.tfvars.example terraform.tfvars
oci session authenticate --profile-name TERRAFORM
```

Completa `terraform.tfvars` con el OCID del padre y un nombre de bucket unico.
El archivo real esta ignorado y no debe incluir claves, tokens ni contrasenas.

## Validar y revisar

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Revisa que el plan contenga solamente un compartment y un bucket nuevos. La
creacion real requiere una decision explicita:

```bash
terraform apply
```

## Configurar el backend de Docker Platform

Despues del apply, consulta:

```bash
terraform output platform_compartment_ocid
terraform output remote_backend_values
```

Copia los ejemplos del entorno elegido sin versionar los archivos reales:

```bash
cd ../docker-platform
cp environments/staging/backend.oci.tfbackend.example environments/staging/backend.oci.tfbackend
cp environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars
```

Completa `backend.oci.tfbackend` con `bucket`, `namespace` y `region`. Usa una
clave exclusiva del entorno, por ejemplo:

```hcl
key = "docker-platform/staging/terraform.tfstate"
```

En `terraform.tfvars`, configura:

```hcl
environment_name = "staging"
compartment_ocid  = "<output platform_compartment_ocid>"
compartment_name  = "application-platform"
```

Inicializa siempre indicando entorno y reconfigurando el backend:

```bash
terraform init -reconfigure \
  -backend-config=environments/staging/backend.oci.tfbackend

terraform plan \
  -var-file=environments/staging/terraform.tfvars
```

No ejecutes el plan de otro entorno contra esta misma clave de state.

## Recursos existentes

Este bootstrap no administra buckets que ya viven en otros compartments. Por
ejemplo, un bucket de contenido preexistente permanece bajo su propio state y
ciclo de vida. El acceso cross-compartment debe declararse de forma minima en la
plataforma que lo consume, sin trasladar ni recrear el bucket.

## Costos

Crear compartments no tiene costo. El bucket usa Object Storage Standard y
consume la cuota compartida del tenancy. El state suele ser pequeno, pero el
versionado conserva revisiones y las operaciones de almacenamiento pueden
generar consumo fuera de la capa gratuita.
