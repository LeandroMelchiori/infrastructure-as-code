output "boot_volume_backup_policy_id" {
  description = "OCID de la política de backup, o null si está deshabilitada"
  value       = try(oci_core_volume_backup_policy.boot[0].id, null)
}

output "boot_volume_backup_policy_assignment_id" {
  description = "OCID de la asignación de backup, o null si está deshabilitada"
  value       = try(oci_core_volume_backup_policy_assignment.boot[0].id, null)
}
