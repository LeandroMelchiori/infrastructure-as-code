output "bucket_name" {
  description = "Nombre del bucket privado de backups"
  value       = oci_objectstorage_bucket.backups.name
}

output "object_storage_namespace" {
  description = "Namespace de OCI Object Storage requerido por SDK y CLI"
  value       = data.oci_objectstorage_namespace.backups.namespace
}

output "region" {
  description = "Region OCI del bucket"
  value       = var.region
}

output "retention_days" {
  description = "Dias que se conserva cada backup"
  value       = var.retention_days
}

output "iam_policy_id" {
  description = "OCID de la policy IAM que limita el acceso al bucket"
  value       = oci_identity_policy.backups.id
}

output "object_permissions" {
  description = "Permisos de objetos concedidos al dynamic group"
  value       = local.object_permissions
}
