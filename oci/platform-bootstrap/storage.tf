data "oci_objectstorage_namespace" "platform" {
  compartment_id = oci_identity_compartment.platform.id
}

resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = oci_identity_compartment.platform.id
  namespace      = data.oci_objectstorage_namespace.platform.namespace

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
