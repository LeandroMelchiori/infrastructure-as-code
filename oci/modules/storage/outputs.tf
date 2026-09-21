output "media_bucket_name" {
  description = "Nombre del bucket media"
  value       = oci_objectstorage_bucket.media.name
}

output "media_bucket_access_type" {
  description = "Tipo de acceso configurado para el bucket"
  value       = oci_objectstorage_bucket.media.access_type
}

output "media_bucket_versioning" {
  description = "Estado del versionado del bucket"
  value       = oci_objectstorage_bucket.media.versioning
}

output "object_storage_lifecycle_policy_id" {
  description = "ID de la lifecycle policy, o null si está deshabilitada"
  value       = try(oci_objectstorage_object_lifecycle_policy.media[0].id, null)
}
