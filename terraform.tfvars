###############################################################################
# Operational (non-secret) configuration.
###############################################################################

infoblox_host         = "gridmaster.example.com"
infoblox_port         = 443
infoblox_sslmode      = false
infoblox_wapi_version = "2.12"

network_view      = "default"
dns_view          = "default"
default_ns_group  = null   # e.g. "ns-group-internal"
restart_if_needed = true

# ---------------------------------------------------------------------------
# Override EA key names ONLY if your Grid's EA definitions differ from these.
# Keys here must match existing NIOS Extensible Attribute definition names.
# ---------------------------------------------------------------------------
# ea_keys = {
#   vlan_id              = "VLAN"
#   isid                 = "I-SID"
#   vrf                  = "VRF"
#   location             = "Location"
#   nettype              = "NetType"
#   discovery            = "Discovery"
#   zone_group           = "Zone Group"
#   subzone_group        = "Subzone Group"
#   xmc_end_system_group = "XMC End System Group"
# }

# ---------------------------------------------------------------------------
# Network containers and their child networks.
# ---------------------------------------------------------------------------
network_containers = {

  corp = {
    cidr     = "10.0.0.0/16"
    comment  = "Corporate site container"
    vrf      = "CORP"
    location = "HQ"
    nettype  = "Internal"

    networks = {
      # Explicit CIDR + reverse zone + EAs
      users = {
        cidr                = "10.0.1.0/24"
        comment             = "User VLAN"
        gateway             = "10.0.1.1"
        vlan_id             = 100
        location            = "HQ-Floor1"
        create_reverse_zone = true
      }

      # Explicit CIDR, no reverse zone, reserve first 5 addresses
      servers = {
        cidr       = "10.0.2.0/24"
        comment    = "Server VLAN"
        gateway    = "10.0.2.1"
        vlan_id    = 200
        reserve_ip = 5
      }

      # Next-available /24 allocated dynamically from the corp container
      guest = {
        prefix_len          = 24
        comment             = "Guest network (auto-allocated)"
        vlan_id             = 300
        create_reverse_zone = true
      }
    }
  }

  lab = {
    cidr    = "172.16.0.0/16"
    comment = "Lab container"
    vrf     = "LAB"

    networks = {
      lab_a = {
        cidr    = "172.16.10.0/24"
        comment = "Lab segment A"
        vlan_id = 1010
      }
    }
  }
}
