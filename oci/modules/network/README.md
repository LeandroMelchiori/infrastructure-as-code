# OCI Network

Módulo local reutilizable que crea la VCN, Internet Gateway, route table,
security list, subnet pública, Network Security Group del servidor y sus reglas
HTTP, HTTPS, SSH y egress.

El root module conserva Compute, VNIC, Reserved Public IP, IAM y los outputs
públicos de la arquitectura. El CIDR de SSH y el mapa estable de puertos web se
reciben como inputs para mantener la política de cada entorno en el root.

El módulo no configura providers, credenciales ni backends. Conserva los nombres
OCI, CIDRs, DNS labels, routing, egress y tags definidos por el root.
