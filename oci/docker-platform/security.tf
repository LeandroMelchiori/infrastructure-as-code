resource "oci_core_network_security_group" "server" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id

  display_name = "${var.project_name}-server-nsg"

  freeform_tags = local.common_tags
}

locals {
  public_web_ports = {
    http  = 80
    https = 443
  }
}

resource "oci_core_network_security_group_security_rule" "web" {
  for_each = local.public_web_ports

  network_security_group_id = oci_core_network_security_group.server.id

  direction   = "INGRESS"
  protocol    = "6"
  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  description = "Allow ${each.key}"

  tcp_options {
    destination_port_range {
      min = each.value
      max = each.value
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.server.id

  direction   = "INGRESS"
  protocol    = "6"
  source      = var.ssh_source_cidr
  source_type = "CIDR_BLOCK"

  description = "Allow SSH"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress" {
  network_security_group_id = oci_core_network_security_group.server.id

  direction        = "EGRESS"
  protocol         = "all"
  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "Allow outbound traffic"
}
