# AGENTS.md

Guía para agentes que trabajen en este repositorio de Infrastructure as Code.

## Propósito del repositorio

Este repositorio documenta y versiona plantillas de infraestructura reutilizables. Cada carpeta de proveedor debe tratarse como una infraestructura independiente, con su propia documentación, variables de ejemplo y flujo de despliegue.

Las infraestructuras actualmente implementadas son:

- `oci/terraform-state`: bootstrap independiente para un bucket privado y versionado dedicado al estado remoto de Terraform.
- `oci/docker-platform`: plataforma Docker sobre Oracle Cloud Infrastructure con networking, Compute, Docker/Compose, Traefik, Vault/KMS, Object Storage, Monitoring/Notifications, backups, Logging, OCIR y base restringida para CI/CD de aplicaciones.

## Estructura relevante

```text
infrastructure-as-code/
├── README.md
├── AGENTS.md
├── .gitignore
└── oci/
    ├── terraform-state/
    │   ├── README.md
    │   ├── *.tf
    │   └── terraform.tfvars.example
    └── docker-platform/
        ├── README.md
        ├── *.tf
        ├── environments/
        │   ├── dev/
        │   ├── staging/
        │   └── prod/
        │       ├── backend.oci.tfbackend.example
        │       └── terraform.tfvars.example
        ├── cloud-init/
        │   ├── bootstrap.yaml.tftpl
        │   ├── deploy-compose-app.py
        │   └── install-ocir-helper.sh.tftpl
        ├── deployment/
        │   ├── README.md
        │   ├── app-config.example.json
        │   ├── compose.example.yml
        │   └── github-actions/
        │       └── deploy.yml.example
        └── proxy/
            └── docker-compose.yml.tftpl
```

## Convenciones generales

- Mantén la documentación en español, siguiendo el tono claro y operativo de los README existentes.
- Conserva la separación entre infraestructura y aplicaciones. No agregues apps concretas a `oci/docker-platform`; esa plantilla solo prepara la plataforma base.
- Usa nombres derivados de `project_name` cuando agregues recursos nuevos, salvo que exista una variable explícita para permitir override.
- Aplica `local.common_tags` a recursos OCI nuevos cuando el provider lo soporte.
- Prefiere variables declaradas en `variables.tf` antes que valores fijos dentro de recursos.
- Mantén los archivos `environments/*/*.example` como documentación segura y sin secretos reales.
- Coloca cada capacidad transversal en un archivo `.tf` propio cuando tenga un ciclo de vida claro (`backup.tf`, `logging.tf`, `registry.tf`, `deployment.tf`).
- Toda capacidad opcional debe actualizar variables, outputs útiles, los ejemplos de cada entorno y el README del módulo.
- Los outputs de recursos opcionales deben devolver mapas vacíos o `null` cuando la función esté deshabilitada, sin evaluar índices inexistentes.

## Flujo obligatorio de trabajo

Antes de modificar una arquitectura o agregar una capa transversal:

1. Revisa la estructura, recursos, variables, outputs, documentación, estado Git y cambios locales existentes.
2. Explica el diseño propuesto y por qué encaja con la arquitectura actual.
3. Enumera los recursos OCI y archivos que se crearán o modificarán.
4. Identifica costos, límites de Free Tier, permisos IAM, efectos sobre la VM y riesgos de destrucción o reemplazo.
5. Separa claramente infraestructura compartida de configuración específica de aplicaciones.
6. Si el usuario exige aprobación del diseño antes de editar, no modifiques ningún archivo hasta recibirla.

Durante la implementación:

- Mantén toda funcionalidad opcional desactivada por defecto.
- No modifiques recursos existentes cuando pueda resolverse con recursos nuevos, documentación o bootstrap para futuras instancias.
- No registres aplicaciones concretas ni uses nombres como TechRetAI, ForoHub u otros proyectos dentro de la plataforma genérica.
- No introduzcas secretos, credenciales, endpoints privados ni datos reales en Terraform, ejemplos, workflows o documentación.
- No ejecutes `terraform apply` durante tareas de análisis o implementación salvo autorización explícita e inequívoca.

Después de implementar, ejecuta desde el módulo modificado:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
git diff --check
```

Puede ejecutarse primero `terraform fmt -recursive` para corregir formato, pero la entrega debe incluir un `fmt -check` limpio.

Si existen el backend y las variables reales de un entorno explícito y la autenticación está disponible:

```bash
terraform init -reconfigure \
  -backend-config=environments/ENTORNO/backend.oci.tfbackend
terraform plan -var-file=environments/ENTORNO/terraform.tfvars
```

Revisa explícitamente que el plan tenga `0 to destroy`, que no reemplace Compute ni otros recursos inesperadamente y que no incluya secretos. Si no puede ejecutarse el plan real, indícalo; no presentes una revisión estática como confirmación proveniente del state.

## Terraform

Trabaja desde la carpeta de la infraestructura concreta:

```bash
cd oci/docker-platform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Solo con los archivos reales de un entorno nombrado y autenticación disponible:

```bash
terraform init -reconfigure \
  -backend-config=environments/ENTORNO/backend.oci.tfbackend
terraform plan -var-file=environments/ENTORNO/terraform.tfvars
```

Para el bootstrap del bucket trabaja desde `oci/terraform-state` y utiliza
`terraform init` sin backend remoto.

Requisitos actuales:

- Terraform `>= 1.12.0`
- Provider `oracle/oci` versión `8.29.0`
- Autenticación OCI por defecto: `InstancePrincipal`
- Región por defecto: `sa-saopaulo-1`

`oci/terraform-state` es una arquitectura bootstrap: crea el bucket antes de que
las demás configuraciones puedan inicializar su backend. Conserva su propio state
local, que debe tratarse como un archivo sensible y respaldarse fuera de Git.

Antes de entregar cambios en Terraform:

- Ejecuta `terraform fmt -check -recursive` en la raíz del módulo modificado.
- Ejecuta `terraform init -backend=false` y `terraform validate` para validación estática.
- Ejecuta `terraform plan` solo cuando sea seguro consultar OCI, el backend real esté disponible y existan variables locales válidas.
- Ejecuta `git diff --check` desde la raíz del repositorio.
- Si no puedes ejecutar una validación por falta de credenciales, provider, red, backend o `terraform.tfvars`, indícalo explícitamente.

## Remote State

- Mantén cada arquitectura Terraform independiente, con su propio backend, variables y ciclo de vida.
- El state remoto de `oci/docker-platform` debe vivir en el bucket dedicado creado por `oci/terraform-state`.
- Nunca mezcles Terraform State con el bucket `media`, logs, backups, imágenes OCIR ni artefactos de deployment.
- No agregues credenciales al bloque `backend`, a `backend.oci.tfbackend.example` ni a Git.
- Conserva compatibilidad con OCI Cloud Shell y autenticación `SecurityToken`/perfiles OCI cuando corresponda.
- Documenta la migración desde state local mediante `terraform init -migrate-state` y exige detener ejecuciones concurrentes antes de migrar.
- El bootstrap `oci/terraform-state` conserva state local; trátalo como sensible y mantenlo fuera de Git.
- No cambies backend y recursos de aplicación en la misma operación sin una razón explícita.
- `dev`, `staging` y `prod` deben usar claves de state distintas. Nunca copies ni reutilices state entre entornos.
- No uses Terraform Workspaces como mecanismo principal de separación.
- `environment_name` es obligatorio y no puede tener un valor por defecto.
- Todo comando con backend o variables debe nombrar el entorno y usar rutas del mismo directorio.
- Usa `terraform init -reconfigure` al cambiar de entorno en un checkout; prefiere checkouts separados para operaciones sensibles.

## Entornos y automatización

- Mantén un único conjunto de archivos `.tf`; las diferencias viven en `environments/dev`, `environments/staging` y `environments/prod`.
- Solo versiona archivos `.example`. Los `terraform.tfvars` y `backend.oci.tfbackend` reales permanecen ignorados en cualquier entorno.
- DEV prioriza bajo costo y puede desactivar capacidades opcionales. SSH público solo puede tratarse como warning en este perfil.
- STAGING debe aproximarse a prod. SSH público es bloqueante y los controles operativos desactivados deben generar advertencias visibles.
- PROD exige monitoring, logging, backups, registry privado e inmutable, Object Storage privado con versionado y SSH restringido.
- Terraform CI y Policy as Code validan los tres perfiles en pull requests. Las ejecuciones manuales exigen selección explícita.
- Drift Detection usa rutas root-owned independientes bajo `/etc/terraform/oci/docker-platform/<environment>/` y comprueba que `environment_name` y la clave del backend coincidan.
- Los workflows que consultan OCI deben usar GitHub Environments separados: `infrastructure-dev`, `infrastructure-staging` e `infrastructure-prod`.
- Configura required reviewers y restricciones de rama en `infrastructure-prod`; esas protecciones viven en GitHub y deben documentarse aunque no sean expresables en YAML.
- Nunca hagas que prod sea el valor por defecto de un input, script, matriz operativa o comando documentado.
- Las políticas pueden variar en severidad por entorno, pero una excepción debe ser concreta, documentada, con propietario, justificación y vencimiento.
- No afirmes que un perfil protege prod si sus controles solo se ejecutan como warning o si el check no es requerido por branch protection.

## Archivos sensibles y estado


No agregues ni sugieras commitear:

- `terraform.tfvars`
- `*.auto.tfvars`
- `*.tfstate`
- `*.tfstate.*`
- `*.tfplan`
- `*.tfbackend`
- `.terraform/`
- `.env`
- `.env.*`
- `*.pem`
- `*.key`

Los archivos `environments/*/*.example` deben mantenerse versionados y solo contener placeholders o valores no sensibles.

## Seguridad y operaciones destructivas

Este repositorio crea infraestructura real en OCI. Actúa con cautela:

- No ejecutes `terraform apply` ni `terraform destroy` salvo petición explícita del usuario.
- No amplíes permisos IAM sin explicar el motivo y el alcance.
- No crees buckets públicos, credenciales OCI estáticas, auth tokens, passwords, claves privadas ni credenciales Docker mediante Terraform.
- Evita hardcodear emails, endpoints de notificación, OCIDs reales o información específica de una aplicación.
- Mantén backups, lifecycle destructivo, logging, monitoring, registry y deployment desactivados por defecto.
- No habilites eliminación de objetos, versiones, imágenes o backups por defecto.
- No agregues políticas de retención irreversibles por defecto.
- Evita abrir SSH a `0.0.0.0/0` como recomendación productiva; úsalo solo como ejemplo de laboratorio, tal como indica la documentación.
- Trata cambios en CIDR, subnets, VCN, KMS, Vault, buckets, boot volumes, dynamic groups y policies como potencialmente disruptivos.
- Revisa especialmente cualquier cambio en `preserve_boot_volume`, `access_type`, `object_storage_versioning`, reglas NSG y políticas IAM.

## Costos y Free Tier

- Nunca afirmes que una funcionalidad es gratuita solo porque usa un servicio OCI o porque la VM sea Always Free.
- Verifica precios y límites actuales en documentación oficial cuando el usuario pregunte por costos o Free Tier.
- Explica por separado costos potenciales de almacenamiento, requests, ingestión, retención, backups, transferencia, runners y notificaciones.
- Recuerda que OCIR consume almacenamiento equivalente a Object Storage Standard y que cuotas gratuitas pueden ser compartidas con otros buckets u objetos.
- Logging puede generar costos de ingestión y retención; backups consumen Block Volume Backup; versionado conserva copias; archive puede cobrar recuperación; GitHub Actions puede consumir minutos y artefactos.
- Una configuración deshabilitada puede no generar consumo, pero no garantiza que activarla permanezca dentro de Free Tier.
- No introduzcas recursos pagos para resolver una tarea si existe una alternativa nativa y simple, pero tampoco sacrifiques seguridad para perseguir gratuidad.

## OCI Docker Platform

La carpeta `oci/docker-platform` define:

- `network.tf`: VCN, Internet Gateway, route table, security list y subnet pública.
- `security.tf`: NSG del servidor, reglas públicas HTTP/HTTPS, SSH configurable y egress.
- `compute.tf`: instancia Oracle Linux 9, shape flexible, VNIC, Reserved Public IP y `cloud-init`.
- `iam.tf`: Dynamic Group e IAM Policy para leer secretos y acceder al bucket.
- `vault.tf`: OCI Vault y KMS Key.
- `storage.tf`: bucket de Object Storage para archivos de aplicaciones.
- `backup.tf`: política y asignación opcionales de backup del boot volume y lifecycle del bucket media.
- `logging.tf`: Log Group, logs personalizados y configuraciones opcionales del Unified Monitoring Agent.
- `registry.tf`: repositorios opcionales de OCI Container Registry y policy de pull mediante Instance Principal.
- `deployment.tf`: policies opcionales por principal de CI/CD y permiso de OCI Run Command para la instancia.
- `observability.tf`: topic, suscripción y alarma opcionales para monitoreo de CPU.
- `environment.tf`: selector obligatorio y validaciones de seguridad específicas por entorno.
- `environments/*/backend.oci.tfbackend.example`: backends sin credenciales y con claves de state independientes.
- `environments/*/terraform.tfvars.example`: parámetros y controles de seguridad por entorno.
- `locals.tf`: nombres derivados y tags comunes.
- `outputs.tf`: salidas de compute, red, Vault/KMS, Object Storage, observabilidad, logging, backups, registry y deployment.
- `cloud-init/bootstrap.yaml.tftpl`: instalación de Docker, OCI CLI, firewalld, estructura `/opt/apps`, helpers opcionales y arranque de Traefik.
- `cloud-init/deploy-compose-app.py`: wrapper privilegiado y fail-closed para deployments por digest.
- `deployment/`: documentación, ejemplos root-owned y workflow genérico de aplicaciones.
- `proxy/docker-compose.yml.tftpl`: Traefik con Docker provider, red externa `proxy`, HTTP->HTTPS y Let's Encrypt HTTP-01.

## Bootstrap y servidor

El bootstrap espera una instancia Oracle Linux 9 y realiza, entre otras cosas:

- instalación de Docker Engine y Docker Compose plugin;
- instalación de OCI CLI;
- activación de `docker` y `firewalld`;
- apertura de SSH, HTTP y HTTPS en firewalld;
- creación de `/opt/apps/proxy`, `/opt/apps/shared` y `/opt/apps/apps`;
- creación de la red Docker externa `proxy`;
- arranque de Traefik con `docker compose up -d`.

Cuando edites `bootstrap.yaml.tftpl` o `docker-compose.yml.tftpl`, revisa que el contenido siga siendo compatible con `templatefile` y con la codificación base64 usada en `compute.tf`.

OCI no permite actualizar `metadata.user_data` de una instancia existente. Conserva el `lifecycle.ignore_changes` aplicado a `metadata["user_data"]`: los cambios de cloud-init deben preparar instancias nuevas sin forzar reemplazos. Para una VM existente, documenta una instalación administrativa puntual y no recrees Compute como atajo.

## Variables importantes

Variables requeridas o de alto impacto:

- `tenancy_ocid`
- `compartment_ocid`
- `compartment_name`
- `environment_name`
- `project_name`
- `oci_auth`
- `oci_config_file_profile`
- `acme_email`
- `ssh_public_key_path`
- `ssh_source_cidr`
- `shape`
- `ocpus`
- `memory_in_gbs`
- `boot_volume_size_in_gbs`
- `image_ocid`
- `media_bucket_name`
- `object_storage_access_type`
- `object_storage_versioning`
- `object_storage_lifecycle_enabled`
- `object_storage_archive_after_days`
- `object_storage_delete_previous_versions_after_days`
- `object_storage_abort_multipart_uploads_after_days`
- `backup_enabled`
- `backup_frequency`
- `backup_type`
- `backup_retention_days`
- `backup_hour_utc`
- `backup_day_of_week`
- `backup_day_of_month`
- `logging_enabled`
- `logging_log_group_name`
- `logging_retention_days`
- `logging_sources`
- `registry_enabled`
- `registry_repository_names`
- `registry_visibility`
- `registry_immutable`
- `registry_freeform_tags`
- `deployment_enabled`
- `deployment_principals`
- `monitoring_enabled`
- `notification_topic_name`
- `notification_protocol`
- `notification_endpoint`
- `cpu_alarm_threshold_percent`
- `cpu_alarm_pending_duration_minutes`
- `cpu_alarm_severity`

Si agregas variables:

- Define `description` y `type`.
- Agrega `default` solo cuando exista un valor seguro y reutilizable.
- Usa bloques `validation` para opciones cerradas o peligrosas.
- Actualiza los `terraform.tfvars.example` de todos los entornos afectados.
- Actualiza el README del módulo si cambia el flujo de uso.

## IAM, Vault y Object Storage

La instancia usa Instance Principal mediante Dynamic Group. No agregues credenciales OCI estáticas al servidor, a contenedores ni a ejemplos.

El bucket de Terraform State pertenece a `oci/terraform-state`; no concedas acceso
a ese bucket al Dynamic Group del servidor ni lo combines con el bucket `media`.

La policy actual permite:

- leer `secret-bundles` en el compartment configurado;
- leer el bucket de medios;
- gestionar objetos dentro del bucket de medios.

Si modificas permisos, mantén el alcance mínimo necesario y prefiere condiciones por nombre de bucket u otro criterio específico cuando sea posible.

## Observabilidad y notificaciones

- Prefiere servicios nativos de OCI Monitoring y Notifications cuando sean suficientes.
- Mantén `monitoring_enabled = false` por defecto.
- Las alarmas deben ser genéricas para la plataforma, no específicas de una aplicación.
- La alarma de CPU debe permitir configurar umbral, duración pendiente y severidad.
- No hardcodees emails ni endpoints. Usa variables sensibles y ejemplos con `null` o placeholders.
- Documenta que suscripciones como EMAIL pueden requerir confirmación fuera de Terraform.
- Añade outputs útiles sin exponer el endpoint sensible.
- Explica costos potenciales de métricas, alarmas, topics, mensajes y protocolos de entrega.

## Backups y recuperación

- Mantén `backup_enabled = false` por defecto.
- Usa una política de backup de OCI Block Volume administrada por Terraform y asígnala al boot volume de la instancia.
- Permite configurar frecuencia, tipo, retención, hora UTC y día cuando corresponda.
- No modeles snapshots o backups permanentes individuales como recursos Terraform.
- No modifiques `compute.tf` si el boot volume puede referenciarse desde el recurso existente.
- No elimines la instancia ni el boot volume al deshabilitar la política.
- Para Object Storage, versionado y lifecycle son opcionales e independientes del backup del boot volume.
- La eliminación de versiones previas debe permanecer `null` por defecto y documentarse como irreversible.
- La limpieza de multipart uploads incompletos puede configurarse sin eliminar objetos completos.
- No habilites archive, delete ni retenciones irreversibles de forma implícita.
- Documenta procedimientos de recuperación; crear una política no equivale a probar un restore.

## Logging centralizado

- Mantén `logging_enabled = false` por defecto.
- Usa OCI Logging y Unified Monitoring Agent para fuentes que requieran agente.
- Las fuentes mínimas soportadas son sistema operativo, cloud-init y Docker; Traefik se captura a través de los logs Docker.
- Mantén nombres de Log Group, retención y fuentes configurables.
- No acoples filtros ni nombres a una aplicación concreta.
- Instala/configura solamente el agente necesario y no agregues credenciales: la ingestión usa Instance Principal.
- Prefiere configuraciones de agente y policies nuevas antes que cambios en Compute.
- Si un cambio de cloud-init no alcanza una VM existente, documéntalo; no fuerces reemplazo.
- Explica costos de ingestión, búsqueda y retención antes de recomendar habilitar todas las fuentes.

## OCI Container Registry

- Mantén `registry_enabled = false` por defecto.
- Crea repositorios a partir de `registry_repository_names`; la cantidad deriva del conjunto y no de un contador separado.
- Los repositorios deben ser privados por defecto. `PUBLIC` requiere decisión explícita.
- No almacenes passwords, auth tokens, claves privadas ni `docker login` persistente en Terraform o Git.
- Compute hace pull mediante `docker-credential-ocir`, OCI CLI e Instance Principal.
- La policy de Compute debe ser de lectura; no concedas push, create o delete a la VM de aplicaciones.
- Usa nombres genéricos y tags comunes; no registres repositorios para una aplicación concreta dentro de la plantilla base.
- `registry_immutable = null` debe preservar repositorios existentes. Deployment requiere establecerlo explícitamente en `true` para impedir sobrescritura de tags SHA.
- Quitar nombres del conjunto puede destruir repositorios e imágenes; destaca ese riesgo al revisar el plan.
- No asumas que OCIR es gratuito: considera almacenamiento Standard, transferencia y acumulación de imágenes inmutables.

## CI/CD de aplicaciones

La CI de infraestructura y la CI/CD de aplicaciones son flujos distintos:

- La CI de este repositorio valida, inicializa y planifica Terraform; nunca construye ni despliega aplicaciones.
- El workflow de test/build/scan/push/deploy vive en el repositorio de cada aplicación.
- La IaC solo proporciona repositorios, IAM mínimo, OCI Run Command y el contrato root-owned del servidor.
- No implementes Kubernetes ni autoscaling salvo una tarea posterior explícita.

Reglas de activación y autenticación:

- Mantén `deployment_enabled = false` por defecto y no registres aplicaciones concretas.
- No crees usuarios OCI, API keys, auth tokens ni secretos para GitHub Actions.
- Mantén autenticación desacoplada mediante principales IAM preexistentes.
- Prefiere OIDC/federación o un runner OCI dedicado y efímero con Instance Principal cuando el flujo completo lo permita.
- No presentes GitHub OIDC hacia OCI/OCIR como turnkey: si requiere Identity Domains, token exchange, cliente adicional o secretos, documéntalo claramente.
- Usa un principal separado por aplicación o dominio de confianza siempre que sea posible.
- Cada principal solo puede `READ`/`UPDATE` los repositorios OCIR exactos declarados; no concedas create, delete o administración general.
- Evita SSH y claves permanentes para deployment. Usa OCI Run Command sin abrir puertos entrantes adicionales.

Contrato del wrapper privilegiado:

- El único comando elevado es `deploy-compose-app <app> <commit-sha>`.
- Debe aceptar exactamente dos argumentos y nunca reenviar argumentos del pipeline a Docker o Docker Compose.
- `<app>` debe validarse y existir en una allowlist local.
- `<commit-sha>` debe ser un SHA Git completo de 40 caracteres hexadecimales minúsculos.
- Repositorio, servicio, Compose, health check e imágenes auxiliares viven bajo `/etc/docker-platform/apps/<app>` y son controlados por root.
- Wrapper, configuración y Compose deben ser `root:root`, no escribibles por `ocarun` ni usuarios no privilegiados.
- Rechaza symlinks, archivos no regulares, paths fuera de los roots autorizados y directorios group/world-writable.
- `ocarun` no debe pertenecer al grupo `docker` ni recibir `NOPASSWD:ALL`; sudoers solo autoriza el wrapper root-owned.
- El wrapper usa APIs estructuradas, argumentos de subprocess en listas y nunca `shell=True`, `eval` ni comandos construidos por el pipeline.

Validación fail-closed de Compose:

- Valida el Compose normalizado antes de cualquier `pull` o `up`.
- Usa un esquema cerrado: todo campo desconocido o no permitido debe fallar.
- Rechaza explícitamente `privileged`, bind mounts, montaje de `/`, Docker socket, `network_mode: host`, `pid: host`, `ipc: host`, `devices`, `cap_add`, builds, ports publicados y comandos Docker arbitrarios.
- Solo permite named volumes declarados y redes compatibles con la plataforma.
- La imagen del servicio desplegable se construye en el servidor desde el repositorio allowlisted; el pipeline no proporciona una URI completa.
- Las imágenes auxiliares deben estar permitidas localmente y fijadas por digest.
- Nunca uses exclusivamente `latest`.

Inmutabilidad, salud y rollback:

- El workflow publica `<repository>:<GITHUB_SHA>` en un repositorio OCIR inmutable.
- El wrapper puede hacer pull del tag SHA para resolverlo, pero `compose pull`, `compose up` y el estado persistido deben usar `repository@sha256:...`.
- El rollback conserva y reutiliza tanto el Compose anterior como su digest anterior; nunca vuelve a ejecutar un tag mutable.
- Descarga la imagen antes de recrear servicios para reducir downtime, pero documenta que una sola VM con Compose no garantiza cero downtime.
- Ejecuta health check local configurado por root y verificación externa desde CI; un fallo debe activar rollback.
- Los logs deben indicar aplicación, SHA, digest y etapa sin imprimir secretos, variables, Compose completo ni salidas potencialmente sensibles.

Riesgo residual obligatorio en la documentación:

- Una imagen maliciosa puede comprometer named volumes, redes, variables, servicios y otros recursos que el Compose autorizado exponga al contenedor.
- También puede explotar vulnerabilidades del kernel o runtime. Restringir el pipeline no convierte una imagen maliciosa en segura.
- OCI Run Command no comunica al wrapper el principal originador; un principal compartido puede solicitar operaciones sobre otras entradas conocidas de la allowlist.
- Usa GitHub Environments, aprobación para producción, branch protection y separación de principales. Aislamiento completo requiere hosts o un broker por dominio de confianza.

## Documentación

Actualiza documentación cuando cambies:

- recursos creados;
- variables;
- outputs;
- comandos de uso;
- reglas de seguridad;
- estructura generada en el servidor;
- supuestos sobre OCI, Docker, Traefik, Vault, KMS u Object Storage.

El README raíz debe seguir describiendo el catálogo general. El README dentro de cada infraestructura debe contener los detalles de esa plantilla.

## Estilo de cambios

- Mantén cambios pequeños y centrados.
- No reformatees archivos no relacionados.
- No elimines comentarios o documentación útil sin reemplazarla por algo mejor.
- Antes de tocar archivos, revisa si hay cambios locales existentes.
- Si encuentras cambios no tuyos, trabaja alrededor de ellos y no los reviertas.
- Muestra o resume el diff final, separando cambios propios de modificaciones preexistentes del usuario.
- Informa qué validaciones pasaron, cuáles no pudieron ejecutarse y por qué.
- No afirmes `0 to destroy` o ausencia de reemplazos si no se ejecutó un plan contra el backend y variables reales.

## Git y commits

- No hagas commit salvo petición explícita.
- Si el usuario pide trabajar en una rama secundaria, no commitees directamente en `main`; crea o usa una rama específica para la tarea.
- Usa commits breves y descriptivos del cambio técnico.
- No menciones inteligencia artificial, agentes ni herramientas de generación en el mensaje de commit.
- No incluyas archivos sensibles, planes, state, configuración de backend ni cambios ajenos a la tarea.
- Revisa `git status`, `git diff --check` y el diff staged antes de confirmar.

## Comandos útiles

Desde la raíz del repositorio:

```bash
rg --files
git status --short
```

Desde `oci/docker-platform`:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform output
```

Con backend y variables reales de un entorno explícito disponibles:

```bash
terraform init -reconfigure \
  -backend-config=environments/ENTORNO/backend.oci.tfbackend
terraform plan -var-file=environments/ENTORNO/terraform.tfvars
```

Usa `terraform apply` y `terraform destroy` únicamente cuando el usuario lo pida de forma explícita.
