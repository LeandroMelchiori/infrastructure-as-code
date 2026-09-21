data "oci_objectstorage_namespace" "platform" {
  compartment_id = var.compartment_ocid
}

module "storage" {
  source = "../modules/storage"

  providers = {
    oci = oci
  }

  compartment_ocid = var.compartment_ocid
  namespace        = data.oci_objectstorage_namespace.platform.namespace
  bucket_name      = local.media_bucket_name
  access_type      = var.object_storage_access_type
  versioning       = var.object_storage_versioning
  common_tags      = local.common_tags

  lifecycle_enabled                   = var.object_storage_lifecycle_enabled
  archive_after_days                  = var.object_storage_archive_after_days
  delete_previous_versions_after_days = var.object_storage_delete_previous_versions_after_days
  abort_multipart_uploads_after_days  = var.object_storage_abort_multipart_uploads_after_days
}
