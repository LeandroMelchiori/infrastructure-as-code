data "oci_objectstorage_namespace" "application" {}

module "storage" {
  source = "../modules/storage"

  compartment_ocid = var.compartment_ocid
  namespace        = data.oci_objectstorage_namespace.application.namespace
  bucket_name      = var.bucket_name
  access_type      = "NoPublicAccess"
  versioning       = var.object_storage_versioning
  common_tags      = local.common_tags

  lifecycle_enabled                         = false
  archive_after_days                        = null
  delete_previous_versions_after_days       = null
  abort_multipart_uploads_after_days        = null
}
