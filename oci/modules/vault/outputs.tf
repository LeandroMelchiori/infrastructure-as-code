output "vault_id" {
  description = "OCID del Vault"
  value       = oci_kms_vault.platform.id
}

output "key_id" {
  description = "OCID de la KMS Key"
  value       = oci_kms_key.platform.id
}
