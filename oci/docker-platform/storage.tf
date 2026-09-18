data "oci_objectstorage_namespace" "platform" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "media" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.platform.namespace

  name = local.media_bucket_name

  access_type  = var.object_storage_access_type
  storage_tier = "Standard"

  versioning = var.object_storage_versioning ? "Enabled" : "Disabled"

  object_events_enabled = false

  freeform_tags = local.common_tags
}
