output "bucket_name" {
  description = "Nombre del bucket privado de la aplicacion"
  value       = module.storage.media_bucket_name
}

output "object_storage_namespace" {
  description = "Namespace de OCI Object Storage requerido por SDK y CLI"
  value       = data.oci_objectstorage_namespace.application.namespace
}

output "region" {
  description = "Region OCI del bucket"
  value       = var.region
}

output "bucket_access_type" {
  description = "Tipo de acceso publico configurado"
  value       = module.storage.media_bucket_access_type
}

output "bucket_versioning" {
  description = "Estado del versionado del bucket"
  value       = module.storage.media_bucket_versioning
}

output "iam_policy_id" {
  description = "OCID de la policy IAM que limita el acceso al bucket"
  value       = oci_identity_policy.application_storage.id
}

output "object_permissions" {
  description = "Permisos de objetos concedidos al grupo IAM"
  value       = local.object_permissions
}
