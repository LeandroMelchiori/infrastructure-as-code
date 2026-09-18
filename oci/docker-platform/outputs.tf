output "server_id" {
  description = "OCID de la instancia"
  value       = oci_core_instance.server.id
}

output "server_public_ip" {
  description = "IP pública reservada"
  value       = oci_core_public_ip.server.ip_address
}

output "server_private_ip" {
  description = "IP privada del servidor"
  value       = data.oci_core_private_ips.server.private_ips[0].ip_address
}

output "vcn_id" {
  description = "OCID de la VCN"
  value       = oci_core_vcn.platform.id
}

output "subnet_id" {
  description = "OCID de la subnet pública"
  value       = oci_core_subnet.public.id
}

output "vault_id" {
  description = "OCID del Vault"
  value       = oci_kms_vault.platform.id
}

output "key_id" {
  description = "OCID de la KMS Key"
  value       = oci_kms_key.platform.id
}
