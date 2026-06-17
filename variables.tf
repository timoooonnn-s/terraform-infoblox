###############################################################################
# Root variables
#
# Credentials live in credentials.auto.tfvars (sensitive, git-ignored).
# Everything else lives in terraform.tfvars.
###############################################################################

# ---------------------------------------------------------------------------
# Connection / credentials
# ---------------------------------------------------------------------------
variable "infoblox_host" {
  description = "Infoblox Grid Manager hostname or IP (WAPI endpoint)."
  type        = string
}

variable "infoblox_username" {
  description = "Infoblox WAPI username."
  type        = string
  sensitive   = true
}

variable "infoblox_password" {
  description = "Infoblox WAPI password."
  type        = string
  sensitive   = true
}

variable "infoblox_port" {
  description = "WAPI HTTPS port."
  type        = number
  default     = 443
}

variable "infoblox_sslmode" {
  description = "Verify the Grid Manager TLS certificate. Set true in production with valid certs."
  type        = bool
  default     = false
}

variable "infoblox_wapi_version" {
  description = "NIOS WAPI version to target."
  type        = string
  default     = "2.12"
}

# ---------------------------------------------------------------------------
# Global DNS / view settings
# ---------------------------------------------------------------------------
variable "network_view" {
  description = "Network view for all containers and networks."
  type        = string
  default     = "default"
}

variable "dns_view" {
  description = "Default DNS view for reverse zones (overridable per network)."
  type        = string
  default     = "default"
}

variable "default_ns_group" {
  description = "Default nameserver group for reverse zones. null = none (overridable per network)."
  type        = string
  default     = null
}

variable "restart_if_needed" {
  description = "Restart member DNS services when reverse zones change."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Extensible Attribute key mapping
#
# These keys MUST match the EA *definition names* already present in your
# NIOS Grid, or apply will fail. Override in terraform.tfvars to match.
# ---------------------------------------------------------------------------
variable "ea_keys" {
  description = "Maps the module's logical attribute names to NIOS Extensible Attribute definition names."
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

# ---------------------------------------------------------------------------
# Network containers + child networks
# (Validation lives in the module; this declaration mirrors the contract.)
# ---------------------------------------------------------------------------
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
      # Provide EXACTLY ONE of cidr (explicit) or prefix_len (next-available).
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
}
