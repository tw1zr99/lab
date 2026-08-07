terraform {
  required_version = ">= 1.9.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
  }
}

provider "proxmox" {
  endpoint = local.cluster.PROXMOX_ENDPOINT
  insecure = var.proxmox_insecure
  min_tls  = "1.3"
}
