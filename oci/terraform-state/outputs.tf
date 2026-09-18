output "state_bucket_name" {
  description = "Nombre del bucket dedicado a Terraform State"
  value       = oci_objectstorage_bucket.state.name
}

output "object_storage_namespace" {
  description = "Namespace de OCI Object Storage requerido por el backend"
  value       = data.oci_objectstorage_namespace.state.namespace
}

output "region" {
  description = "Región del bucket de Terraform State"
  value       = var.region
}
