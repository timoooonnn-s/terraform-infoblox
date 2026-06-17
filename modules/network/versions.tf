terraform {
  required_version = ">= 1.3.0"

  required_providers {
    infoblox = {
      source  = "infobloxopen/infoblox"
      version = "~> 2.0, <= 2.12.0"
    }
  }
}
