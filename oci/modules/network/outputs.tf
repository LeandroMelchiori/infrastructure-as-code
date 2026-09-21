output "vcn_id" {
  description = "OCID de la VCN"
  value       = oci_core_vcn.platform.id
}

output "public_subnet_id" {
  description = "OCID de la subnet pública"
  value       = oci_core_subnet.public.id
}
