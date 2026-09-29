locals {
  server_name = "${var.project_name}-server"

  media_bucket_name = (
    var.media_bucket_name != null
    ? var.media_bucket_name
    : "${var.project_name}-media"
  )

  notification_topic_name = (
    var.notification_topic_name != null
    ? var.notification_topic_name
    : "${var.project_name}-alerts"
  )

  registry_domain = "ocir.${var.region}.oci.oraclecloud.com"

  external_object_storage_permissions = {
    READ       = ["OBJECT_INSPECT", "OBJECT_READ"]
    WRITE_ONCE = ["OBJECT_CREATE"]
    READ_WRITE = ["OBJECT_INSPECT", "OBJECT_READ", "OBJECT_CREATE", "OBJECT_OVERWRITE"]
  }

  external_object_storage_policy_statements = flatten([
    for name in sort(keys(var.external_object_storage_buckets)) : [
      "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to read buckets in compartment id ${trimspace(var.external_object_storage_buckets[name].compartment_ocid)} where target.bucket.name = '${trimspace(var.external_object_storage_buckets[name].bucket_name)}'",
      "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to manage objects in compartment id ${trimspace(var.external_object_storage_buckets[name].compartment_ocid)} where all {target.bucket.name = '${trimspace(var.external_object_storage_buckets[name].bucket_name)}', any {${join(", ", [for permission in local.external_object_storage_permissions[var.external_object_storage_buckets[name].access] : "request.permission='${permission}'"])}}}"
    ]
  ])

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
