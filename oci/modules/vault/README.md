# OCI Vault y KMS

Módulo local reutilizable que crea un OCI Vault y una KMS Key AES de 32 bytes.
Conserva Vault `DEFAULT`, protección `SOFTWARE` y rotación automática
deshabilitada.

El módulo no configura providers, credenciales, IAM ni backends. El root module
proporciona compartment, nombre estable del proyecto y tags, y conserva los
outputs públicos de la arquitectura.
