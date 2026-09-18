# OCI Terraform State

Arquitectura bootstrap independiente para crear el bucket de OCI Object Storage
utilizado por los backends remotos de Terraform.

Este bucket es exclusivo para state. No almacena archivos de aplicaciones y no
reemplaza al bucket `media` de `oci/docker-platform`.

## Recursos creados

- un bucket privado de OCI Object Storage;
- versionado de objetos habilitado;
- tags que identifican el propósito del bucket;
- protección `prevent_destroy` contra borrado accidental desde Terraform.

OCI Object Storage cifra los objetos en reposo. El versionado permite recuperar
una versión anterior del state ante una actualización incorrecta o un borrado.

## Requisito de bootstrap

El backend debe existir antes de ejecutar `terraform init` en las arquitecturas
que lo consumen. Por eso esta configuración usa state local deliberadamente.

Protege y respalda su `terraform.tfstate` fuera de Git. No lo almacenes dentro del
mismo bucket que esta configuración administra, porque se introduciría una
dependencia circular durante el bootstrap y la recuperación.

## Configuración

```bash
cd oci/terraform-state
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con el OCID del compartment y un nombre de bucket único.
El archivo está ignorado por Git y no debe contener claves, tokens ni contraseñas.

## OCI Cloud Shell

Cloud Shell incluye Terraform y OCI CLI. Verifica que Terraform sea 1.12.0 o
posterior:

```bash
terraform version
```

Para usar un perfil temporal en lugar de una clave API:

```bash
oci session authenticate --profile-name TERRAFORM
```

Después configura localmente:

```hcl
oci_auth                = "SecurityToken"
oci_config_file_profile = "TERRAFORM"
```

El token es temporal. Si expira durante una operación, renueva la sesión antes de
volver a ejecutar Terraform.

## Crear el bucket

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Consulta los valores necesarios para configurar otros backends:

```bash
terraform output state_bucket_name
terraform output object_storage_namespace
terraform output region
```

## Permisos IAM

La identidad que crea el bucket necesita permisos de Object Storage en el
compartment. Las identidades que ejecuten Terraform contra el backend necesitan,
como mínimo, inspeccionar, crear, leer y eliminar objetos en este bucket. El
backend nativo crea un objeto de bloqueo junto al state.

Restringe la policy al bucket dedicado. Un patrón para un grupo de operadores es:

```text
Allow group <grupo-terraform> to read buckets in compartment <compartment>
Allow group <grupo-terraform> to manage objects in compartment <compartment> where target.bucket.name = '<bucket-state>'
```

No concedas acceso a este bucket al Dynamic Group de las aplicaciones o del
servidor Docker.

## Protección contra borrado

`prevent_destroy` hace que `terraform destroy` falle mientras el recurso exista.
Para retirar el bucket se requiere una decisión explícita: preservar primero los
states y sus versiones, retirar la protección en el código y volver a revisar el
plan. Nunca vacíes ni elimines el bucket como parte de un cambio de aplicación.
