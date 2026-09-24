# OCI Application Storage

Raiz Terraform independiente para crear un bucket privado de Object Storage y conceder a un grupo IAM preexistente acceso minimo a los documentos de una aplicacion.

Esta plantilla prepara la infraestructura de persistencia. No crea usuarios, API keys, claves privadas ni configuracion de aplicaciones.

## Recursos creados

- bucket Object Storage privado en tier `Standard`;
- policy IAM limitada al nombre exacto del bucket;
- permisos para inspeccionar, leer y crear objetos;
- permiso opcional para sobrescribir objetos, desactivado por defecto;
- outputs con bucket, namespace, region y policy.

No se conceden permisos de borrado de objetos o buckets. El versionado y el lifecycle permanecen desactivados por defecto.

## Dependencias

- Terraform `>= 1.12.0`;
- provider `oracle/oci` `8.29.0`;
- compartment OCI existente;
- grupo IAM existente;
- bucket remoto de Terraform State creado mediante [`../terraform-state`](../terraform-state/).

## Preparacion

```bash
cd oci/application-storage
cp terraform.tfvars.example terraform.tfvars
cp backend.oci.tfbackend.example backend.oci.tfbackend
```

Completa ambos archivos locales. Estan ignorados por Git y no deben incluirse en commits, capturas o canales publicos.

El `bucket_name` debe coincidir con `OCI_BUCKET_NAME` de la aplicacion. Para NuevaMente, el nombre acordado en NM-02 es `nuevamente-contenidos-educativos`, sujeto a disponibilidad y validacion en la tenancy.

## Autenticacion

La opcion preferida en un runner o Compute OCI es `InstancePrincipal`. Para el bootstrap desde una estacion local se admite `APIKey` mediante un perfil en `~/.oci/config`; en OCI Cloud Shell puede utilizarse `SecurityToken`.

La API key se crea manualmente para un usuario existente y el usuario se agrega al grupo indicado por `iam_group_name`. La clave privada nunca se almacena en Terraform ni en Git.

## Inicializacion y validacion

```bash
terraform fmt -check -recursive
terraform init -reconfigure -backend-config=backend.oci.tfbackend
terraform validate
terraform plan -var-file=terraform.tfvars
```

Antes de aplicar, revisa que el plan no destruya ni reemplace recursos inesperadamente. `terraform apply` requiere autorizacion explicita y debe ejecutarse solo despues de revisar el plan.

## Prueba manual de subida y descarga

Despues de aplicar, consulta los outputs:

```bash
terraform output bucket_name
terraform output object_storage_namespace
terraform output region
```

Con un perfil OCI perteneciente al grupo autorizado:

```bash
oci os object put --namespace-name REEMPLAZAR_NAMESPACE --bucket-name REEMPLAZAR_BUCKET --name smoke-test.txt --file smoke-test.txt --profile DEFAULT
oci os object get --namespace-name REEMPLAZAR_NAMESPACE --bucket-name REEMPLAZAR_BUCKET --name smoke-test.txt --file smoke-test-descargado.txt --profile DEFAULT
```

El permiso de borrado no forma parte de la policy. La limpieza del objeto de prueba corresponde a un administrador y debe realizarse conscientemente.

## Costos y Always Free

Object Storage es elegible para la asignacion Always Free publicada por Oracle, pero el limite se comparte a nivel de tenancy. La plantilla no puede garantizar costo cero si la tenancy ya consume la cuota gratuita o supera el limite mensual de requests.

Verifica antes de aplicar:

- [Recursos Always Free de OCI](https://docs.oracle.com/es-ww/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Referencia IAM de Object Storage](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm)
- [Claves y OCIDs requeridos](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm)

## Relacion con la aplicacion

La aplicacion debe recibir por variables de entorno el bucket, namespace y region expuestos por Terraform. El cliente de aplicacion, sus nombres de objeto y su manejo de errores pertenecen al repositorio de la aplicacion, no a esta plantilla.
