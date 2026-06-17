output "network_containers" {
  description = "Created network containers (id and CIDR)."
  value       = module.infoblox_networks.network_containers
}

output "networks" {
  description = "Created child networks (id and resolved CIDR, including next-available allocations)."
  value       = module.infoblox_networks.networks
}

output "reverse_zones" {
  description = "Created reverse DNS zones (id and fqdn)."
  value       = module.infoblox_networks.reverse_zones
}
