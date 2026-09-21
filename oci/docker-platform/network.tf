module "network" {
  source = "../modules/network"

  providers = {
    oci = oci
  }

  compartment_ocid   = var.compartment_ocid
  project_name       = var.project_name
  vcn_cidr           = var.vcn_cidr
  public_subnet_cidr = var.public_subnet_cidr
  common_tags        = local.common_tags
}
