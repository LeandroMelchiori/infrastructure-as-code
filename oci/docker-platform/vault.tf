module "vault" {
  source = "../modules/vault"

  providers = {
    oci = oci
  }

  compartment_ocid = var.compartment_ocid
  project_name     = var.project_name
  common_tags      = local.common_tags
}
