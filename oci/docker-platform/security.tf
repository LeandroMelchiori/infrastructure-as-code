locals {
  public_web_ports = merge(
    { http = 80 },
    var.https_enabled ? { https = 443 } : {}
  )
}
