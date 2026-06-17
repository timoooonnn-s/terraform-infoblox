###############################################################################
# Module variables + input validation
###############################################################################

variable "network_view" {
  description = "Network view for all containers and networks."
  type        = string
  default     = "default"
}

variable "dns_view" {
  description = "Default DNS view for reverse zones."
  type        = string
  default     = "default"
}

variable "default_ns_group" {
  description = "Default nameserver group for reverse zones (null = none)."
  type        = string
  default     = null
}

variable "restart_if_needed" {
  description = "Restart member DNS services when reverse zones change."
  type        = bool
  default     = true
}

variable "ea_keys" {
  description = "Maps logical attribute names to NIOS Extensible Attribute definition names."
  type = object({
    vlan_id              = string
    isid                 = string
    vrf                  = string
    location             = string
    nettype              = string
    discovery            = string
    zone_group           = string
    subzone_group        = string
    xmc_end_system_group = string
  })
  default = {
    vlan_id              = "VLAN"
    isid                 = "I-SID"
    vrf                  = "VRF"
    location             = "Location"
    nettype              = "NetType"
    discovery            = "Discovery"
    zone_group           = "Zone Group"
    subzone_group        = "Subzone Group"
    xmc_end_system_group = "XMC End System Group"
  }
}

variable "network_containers" {
  description = "Map of network containers, each with a map of child networks."
  type = map(object({
    cidr                 = string
    comment              = optional(string)
    vlan_id              = optional(number)
    isid                 = optional(number)
    vrf                  = optional(string)
    location             = optional(string)
    nettype              = optional(string)
    discovery            = optional(string)
    zone_group           = optional(string)
    subzone_group        = optional(string)
    xmc_end_system_group = optional(string)
    extra_ext_attrs      = optional(map(string), {})

    networks = optional(map(object({
      cidr       = optional(string)
      prefix_len = optional(number)

      comment    = optional(string)
      gateway    = optional(string)
      reserve_ip = optional(number, 0)

      create_reverse_zone   = optional(bool, false)
      reverse_zone_ns_group = optional(string)
      reverse_zone_view     = optional(string)

      vlan_id              = optional(number)
      isid                 = optional(number)
      vrf                  = optional(string)
      location             = optional(string)
      nettype              = optional(string)
      discovery            = optional(string)
      zone_group           = optional(string)
      subzone_group        = optional(string)
      xmc_end_system_group = optional(string)
      extra_ext_attrs      = optional(map(string), {})
    })), {})
  }))
  default = {}

  # --- Each network must define exactly one of cidr or prefix_len ----------
  validation {
    condition = alltrue(flatten([
      for ck, c in var.network_containers : [
        for nk, n in c.networks :
        (n.cidr != null) != (n.prefix_len != null)
      ]
    ]))
    error_message = "Each network must set exactly one of 'cidr' (explicit) or 'prefix_len' (next-available)."
  }

  # --- Container VLAN ID range --------------------------------------------
  validation {
    condition = alltrue([
      for ck, c in var.network_containers :
      c.vlan_id == null ? true : (c.vlan_id >= 1 && c.vlan_id <= 4094)
    ])
    error_message = "Container VLAN IDs must be between 1 and 4094."
  }

  # --- Network VLAN ID range ----------------------------------------------
  validation {
    condition = alltrue(flatten([
      for ck, c in var.network_containers : [
        for nk, n in c.networks :
        n.vlan_id == null ? true : (n.vlan_id >= 1 && n.vlan_id <= 4094)
      ]
    ]))
    error_message = "Network VLAN IDs must be between 1 and 4094."
  }

  # --- I-SID range (24-bit) for containers and networks -------------------
  validation {
    condition = alltrue(concat(
      [for ck, c in var.network_containers :
      c.isid == null ? true : (c.isid >= 0 && c.isid <= 16777215)],
      flatten([for ck, c in var.network_containers : [
        for nk, n in c.networks :
        n.isid == null ? true : (n.isid >= 0 && n.isid <= 16777215)
      ]])
    ))
    error_message = "I-SID values must be between 0 and 16777215 (24-bit)."
  }

  # --- Duplicate CIDR detection (containers + explicit networks) ----------
  # Pure-HCL static check. Full subnet-containment/overlap is NOT expressible
  # in HCL; NIOS server-side validation is the backstop for those.
  validation {
    condition = length(distinct(concat(
      [for ck, c in var.network_containers : c.cidr],
      flatten([for ck, c in var.network_containers : [
        for nk, n in c.networks : n.cidr if n.cidr != null
      ]])
      ))) == length(concat(
      [for ck, c in var.network_containers : c.cidr],
      flatten([for ck, c in var.network_containers : [
        for nk, n in c.networks : n.cidr if n.cidr != null
      ]])
    ))
    error_message = "Duplicate CIDR detected across containers and/or explicitly-defined networks."
  }
}
