# OCI Application Backups

Raiz Terraform independiente para guardar los backups de la base de datos de una aplicacion en Object Storage, con retencion automatica y acceso minimo para la instancia que los genera.

Esta plantilla no crea usuarios, API keys, dynamic groups ni scripts de backup. El script que genera y sube cada backup pertenece al repositorio de la aplicacion.

## Recursos creados

- bucket Object Storage privado en tier `Standard`, sin versionado ni acceso publico;
- regla de ciclo de vida que borra cada backup a los `retention_days` dias (30 por defecto) y aborta las subidas multiparte incompletas despues de un dia;
- policy IAM limitada al nombre exacto del bucket que concede al dynamic group de la instancia:
  - leer el bucket;
  - listar y crear objetos;
  - leer objetos, si `allow_read` es `true` (valor por defecto), para probar restauraciones desde la misma instancia;
- permiso para que el servicio Object Storage de la region ejecute la regla de ciclo de vida sobre ese bucket.

La instancia no recibe `OBJECT_DELETE` ni `OBJECT_OVERWRITE`: aunque se comprometa, no puede borrar ni sobrescribir backups. El borrado lo hace solo la regla de ciclo de vida.

## Dependencias

- Terraform `>= 1.12.0`;
- provider `oracle/oci` `8.29.0`;
- compartment OCI existente;
- dynamic group existente que identifique a la instancia. En [`../docker-platform`](../docker-platform/) es `<project_name>-server-dg`;
- bucket remoto de Terraform State creado mediante [`../terraform-state`](../terraform-state/).

## Preparacion

```bash
cd oci/application-backups
cp terraform.tfvars.example terraform.tfvars
cp backend.oci.tfbackend.example backend.oci.tfbackend
```

Completa ambos archivos locales. Estan ignorados por Git y no deben incluirse en commits, capturas o canales publicos. Usa una `key` de backend distinta para cada aplicacion.

## Inicializacion y validacion

```bash
terraform fmt -check -recursive
terraform init -reconfigure -backend-config=backend.oci.tfbackend
terraform validate
terraform plan -var-file=terraform.tfvars
```

El plan esperado crea tres recursos: bucket, policy y regla de ciclo de vida, sin destruir ni reemplazar nada. `terraform apply` requiere autorizacion explicita.

La regla de ciclo de vida depende de la policy. Si el apply falla con un error de permisos del servicio Object Storage, la policy todavia no se propago: espera un minuto y repite `terraform apply`.

## Uso desde la instancia

Con Instance Principal no hacen falta credenciales en la VM. Con la OCI CLI:

```bash
oci os object put --auth instance_principal --namespace NAMESPACE --bucket-name BUCKET --name postgres/backup.dump --file backup.dump --no-overwrite
oci os object list --auth instance_principal --namespace NAMESPACE --bucket-name BUCKET --prefix postgres/
oci os object get --auth instance_principal --namespace NAMESPACE --bucket-name BUCKET --name postgres/backup.dump --file backup.dump
```

Los nombres de objeto deberian incluir la fecha, para no chocar con `--no-overwrite` y para encontrar el mas reciente ordenando por nombre.

## Costos y Always Free

Object Storage es elegible para la asignacion Always Free publicada por Oracle, pero el limite se comparte a nivel de tenancy. El costo depende del tamano de cada backup multiplicado por los dias de retencion. Verifica antes de aplicar:

- [Recursos Always Free de OCI](https://docs.oracle.com/es-ww/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Reglas de ciclo de vida de Object Storage](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm)
- [Referencia IAM de Object Storage](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm)
