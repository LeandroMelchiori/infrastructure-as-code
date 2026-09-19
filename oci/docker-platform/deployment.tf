resource "oci_identity_policy" "deployment_principal" {
  for_each = var.deployment_enabled ? var.deployment_principals : {}

  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-deploy-${each.key}"
  description    = "Permisos minimos del principal ${each.key} para publicar y solicitar deployments"

  statements = concat(
    [
      "Allow ${each.value.principal_type} ${each.value.principal_name} to manage instance-agent-command-family in compartment ${var.compartment_name}"
    ],
    flatten([
      for repository_name in each.value.repository_names : [
        "Allow ${each.value.principal_type} ${each.value.principal_name} to read repos in compartment ${var.compartment_name} where target.repo.name = '${repository_name}'",
        "Allow ${each.value.principal_type} ${each.value.principal_name} to manage repos in compartment ${var.compartment_name} where all { target.repo.name = '${repository_name}', request.permission = 'REPOSITORY_UPDATE' }"
      ]
    ])
  )
}

resource "oci_identity_policy" "deployment_instance" {
  count = var.deployment_enabled ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-deployment-instance-policy"
  description    = "Permite a la instancia recibir comandos mediante OCI Run Command"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.server.name} to use instance-agent-command-execution-family in compartment ${var.compartment_name} where request.instance.id = target.instance.id"
  ]
}
