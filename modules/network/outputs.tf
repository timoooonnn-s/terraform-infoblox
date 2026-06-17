output "network_containers" {
  description = "Created network containers."
  value = {
    for k, r in infoblox_ipv4_network_container.this : k => {
      id   = r.id
      cidr = r.cidr
    }
  }
}

output "networks" {
  description = "Created child networks with resolved CIDR (next-available allocations resolved post-apply)."
  value = {
    for k, r in infoblox_ipv4_network.this : k => {
      id   = r.id
      cidr = r.cidr
    }
  }
}

output "reverse_zones" {
  description = "Created reverse DNS zones."
  value = {
    for k, r in infoblox_zone_auth.reverse : k => {
      id   = r.id
      fqdn = r.fqdn
    }
  }
}
