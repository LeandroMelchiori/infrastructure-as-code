data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "server" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  display_name = local.server_name
  shape        = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = module.network.public_subnet_id
    assign_public_ip = false

    display_name   = "${local.server_name}-vnic"
    hostname_label = substr(replace(local.server_name, "-", ""), 0, 15)

    nsg_ids = [
      module.network.server_nsg_id
    ]
  }

  source_details {
    source_type = "image"

    source_id = var.image_ocid != null ? var.image_ocid : data.oci_core_images.oracle_linux.images[0].id

    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))

    user_data = base64encode(
      templatefile(
        "${path.module}/cloud-init/bootstrap.yaml.tftpl",
        {
          traefik_compose_b64 = base64encode(
            templatefile(
              "${path.module}/proxy/docker-compose.yml.tftpl",
              {
                acme_email    = var.acme_email
                traefik_image = var.traefik_image
              }
            )
          )
          registry_enabled = var.registry_enabled
          registry_helper_b64 = base64encode(
            templatefile(
              "${path.module}/cloud-init/install-ocir-helper.sh.tftpl",
              {
                registry_domain = local.registry_domain
              }
            )
          )
          deployment_enabled     = var.deployment_enabled
          deployment_wrapper_b64 = base64encode(file("${path.module}/cloud-init/deploy-compose-app.py"))
        }
      )
    )
  }

  preserve_boot_volume = false

  freeform_tags = local.common_tags

  # OCI no permite actualizar user_data despues del launch. Ignorarlo evita
  # reemplazar una instancia existente al evolucionar el bootstrap.
  lifecycle {
    ignore_changes = [metadata["user_data"]]
  }
}

data "oci_core_vnic_attachments" "server" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.server.id
}

data "oci_core_private_ips" "server" {
  vnic_id = data.oci_core_vnic_attachments.server.vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "server" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"

  display_name = "${local.server_name}-ip"

  private_ip_id = data.oci_core_private_ips.server.private_ips[0].id

  freeform_tags = local.common_tags
}
