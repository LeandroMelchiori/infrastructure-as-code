resource "oci_core_vcn" "platform" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]

  display_name = "${var.project_name}-vcn"
  dns_label    = substr(replace(var.project_name, "-", ""), 0, 15)

  freeform_tags = var.common_tags
}

resource "oci_core_internet_gateway" "platform" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.platform.id

  display_name = "${var.project_name}-internet-gateway"
  enabled      = true

  freeform_tags = var.common_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.platform.id

  display_name = "${var.project_name}-public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.platform.id
  }

  freeform_tags = var.common_tags
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.platform.id

  display_name = "${var.project_name}-public-security-list"

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  freeform_tags = var.common_tags
}

resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.platform.id

  cidr_block   = var.public_subnet_cidr
  display_name = "${var.project_name}-public-subnet"
  dns_label    = "public"

  route_table_id = oci_core_route_table.public.id

  security_list_ids = [
    oci_core_security_list.public.id
  ]

  prohibit_public_ip_on_vnic = false

  freeform_tags = var.common_tags
}

resource "oci_core_network_security_group" "server" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.platform.id

  display_name = "${var.project_name}-server-nsg"

  freeform_tags = var.common_tags
}

resource "oci_core_network_security_group_security_rule" "web" {
  for_each = var.public_web_ports

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
