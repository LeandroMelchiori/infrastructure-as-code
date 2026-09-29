output "platform_compartment_ocid" {
  description = "OCID del compartment creado para la plataforma"
  value       = oci_identity_compartment.platform.id
}

output "platform_compartment_name" {
  description = "Nombre del compartment creado para la plataforma"
  value       = oci_identity_compartment.platform.name
}

output "state_bucket_name" {
  description = "Nombre del bucket dedicado a Terraform State"
  value       = oci_objectstorage_bucket.terraform_state.name
}

output "object_storage_namespace" {
  description = "Namespace requerido por el backend OCI de Terraform"
  value       = data.oci_objectstorage_namespace.platform.namespace
}

output "region" {
  description = "Region configurada para el bootstrap"
  value       = var.region
}

output "remote_backend_values" {
  description = "Valores no sensibles para completar un archivo backend.oci.tfbackend local"
  value = {
    bucket    = oci_objectstorage_bucket.terraform_state.name
    namespace = data.oci_objectstorage_namespace.platform.namespace
    region    = var.region
  }
}
