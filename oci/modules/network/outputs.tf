output "vcn_id" {
  description = "OCID de la VCN"
  value       = oci_core_vcn.platform.id
}

output "public_subnet_id" {
  description = "OCID de la subnet pública"
  value       = oci_core_subnet.public.id
}

output "server_nsg_id" {
  description = "OCID del Network Security Group asociado al servidor"
  value       = oci_core_network_security_group.server.id
}
