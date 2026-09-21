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
