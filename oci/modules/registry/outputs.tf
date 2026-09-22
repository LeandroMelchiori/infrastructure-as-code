output "registry_repository_count" {
  description = "Cantidad de repositorios OCIR administrados"
  value       = length(oci_artifacts_container_repository.platform)
}

output "registry_repository_names" {
  description = "Nombres de los repositorios OCIR creados"
  value       = sort(keys(oci_artifacts_container_repository.platform))
}

output "registry_repository_urls" {
  description = "URLs completas de los repositorios OCIR, indexadas por nombre"
  value = {
    for name, repository in oci_artifacts_container_repository.platform :
    name => "${var.registry_domain}/${repository.namespace}/${repository.display_name}"
  }
}
