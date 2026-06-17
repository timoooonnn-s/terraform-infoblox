###############################################################################
# Root module: provider configuration + call to the reusable network module
###############################################################################

provider "infoblox" {
  server       = var.infoblox_host
  username     = var.infoblox_username
  password     = var.infoblox_password
  port         = var.infoblox_port
  sslmode      = var.infoblox_sslmode
  wapi_version = var.infoblox_wapi_version
}

module "infoblox_networks" {
  source = "./modules/network"

  network_view      = var.network_view
  dns_view          = var.dns_view
  default_ns_group  = var.default_ns_group
  restart_if_needed = var.restart_if_needed
  ea_keys           = var.ea_keys

  network_containers = var.network_containers
}
