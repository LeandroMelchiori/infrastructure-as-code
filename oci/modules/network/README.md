# OCI Network Core

Módulo local reutilizable que crea la VCN, Internet Gateway, route table,
security list y subnet pública de la plataforma.

Este checkpoint no administra Network Security Groups ni sus reglas. El root
module conserva Compute, NSG, VNIC, Reserved Public IP, IAM y los outputs
públicos de la arquitectura.

El módulo no configura providers, credenciales ni backends. Conserva los nombres
OCI, CIDRs, DNS labels, routing, egress y tags definidos por el root.
