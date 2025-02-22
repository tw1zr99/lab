terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://hades.lan:8006/api2/json"
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "k8s_master_01" {
  name        = "k8s-master-01"
  count       = 1
  target_node = var.proxmox_host

  clone      = var.template_name
  full_clone = true

  agent    = 1
  os_type  = "cloud-init"
  cores    = 2
  sockets  = 1
  cpu_type = "host"
  memory   = 3072
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot    = "scsi0"
    size    = "50G"
    type    = "disk"
    storage = "local-lvm"
    discard = true
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.nic_name
  }

  lifecycle {
    ignore_changes = [
      network
    ]
  }
}
