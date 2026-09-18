data "oci_objectstorage_namespace" "state" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "state" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.state.namespace

  name         = var.state_bucket_name
  access_type  = "NoPublicAccess"
  storage_tier = "Standard"
  versioning   = "Enabled"

  object_events_enabled = false

  freeform_tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}
