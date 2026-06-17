###############################################################################
# Locals: flatten the nested structure and build ext_attrs payloads
###############################################################################

locals {
  # Flatten { container => { network => {...} } } into "container/network" => {...}
  # The leading {} guarantees merge() always receives >= 1 argument, even when
  # no containers (or no networks) are defined.
  networks_flat = merge(concat([{}], [
    for ck, c in var.network_containers : {
      for nk, n in c.networks :
      "${ck}/${nk}" => merge(n, { container_key = ck })
    }
  ])...)

  # Extensible attributes for each container: only non-null values are emitted,
  # then merged with any free-form extra_ext_attrs.
  container_ext_attrs = {
    for ck, c in var.network_containers : ck => jsonencode(merge(
      {
        for k, v in {
          (var.ea_keys.vlan_id)              = c.vlan_id
          (var.ea_keys.isid)                 = c.isid
          (var.ea_keys.vrf)                  = c.vrf
          (var.ea_keys.location)             = c.location
          (var.ea_keys.nettype)              = c.nettype
          (var.ea_keys.discovery)            = c.discovery
          (var.ea_keys.zone_group)           = c.zone_group
          (var.ea_keys.subzone_group)        = c.subzone_group
          (var.ea_keys.xmc_end_system_group) = c.xmc_end_system_group
        } : k => v if v != null
      },
      c.extra_ext_attrs
    ))
  }

  # Extensible attributes for each child network.
  network_ext_attrs = {
    for key, n in local.networks_flat : key => jsonencode(merge(
      {
        for k, v in {
          (var.ea_keys.vlan_id)              = n.vlan_id
          (var.ea_keys.isid)                 = n.isid
          (var.ea_keys.vrf)                  = n.vrf
          (var.ea_keys.location)             = n.location
          (var.ea_keys.nettype)              = n.nettype
          (var.ea_keys.discovery)            = n.discovery
          (var.ea_keys.zone_group)           = n.zone_group
          (var.ea_keys.subzone_group)        = n.subzone_group
          (var.ea_keys.xmc_end_system_group) = n.xmc_end_system_group
        } : k => v if v != null
      },
      n.extra_ext_attrs
    ))
  }
}

###############################################################################
# Network containers
###############################################################################

resource "infoblox_ipv4_network_container" "this" {
  for_each = var.network_containers

  network_view = var.network_view
  cidr         = each.value.cidr
  comment      = coalesce(each.value.comment, each.key)
  ext_attrs    = local.container_ext_attrs[each.key]

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# Child networks
#
# - Explicit:        cidr is set        -> created at that CIDR.
# - Next-available:  prefix_len is set  -> allocated from the parent container.
###############################################################################

resource "infoblox_ipv4_network" "this" {
  for_each = local.networks_flat

  network_view = var.network_view

  # Explicit allocation
  cidr = each.value.cidr

  # Next-available allocation from the parent container
  parent_cidr = each.value.cidr == null ? (
    infoblox_ipv4_network_container.this[each.value.container_key].cidr
  ) : null
  allocate_prefix_len = each.value.prefix_len
  object              = each.value.cidr == null ? "networkcontainer" : null

  gateway    = each.value.gateway
  reserve_ip = each.value.reserve_ip
  comment    = coalesce(each.value.comment, each.key)
  ext_attrs  = local.network_ext_attrs[each.key]

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# Reverse DNS zones (opt-in per network)
#
# fqdn resolves at apply time for next-available networks via the computed
# network CIDR. for_each keys are static, so the plan is valid.
###############################################################################

resource "infoblox_zone_auth" "reverse" {
  for_each = {
    for key, n in local.networks_flat : key => n if n.create_reverse_zone
  }

  fqdn        = coalesce(each.value.cidr, infoblox_ipv4_network.this[each.key].cidr)
  zone_format = "IPV4"
  view        = coalesce(each.value.reverse_zone_view, var.dns_view)
  ns_group    = each.value.reverse_zone_ns_group != null ? each.value.reverse_zone_ns_group : var.default_ns_group
  comment     = "Reverse zone for ${each.key}"

  restart_if_needed = var.restart_if_needed

  lifecycle {
    prevent_destroy = true
  }
}
