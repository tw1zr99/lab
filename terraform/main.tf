locals {
  talos_iso_file_name = "talos-${trimprefix(var.talos_version, "v")}-metal-amd64.iso"
}

resource "proxmox_download_file" "talos_iso" {
  for_each = var.talos_nodes

  content_type       = "iso"
  datastore_id       = var.iso_datastore_id
  node_name          = each.value.proxmox_node
  file_name          = local.talos_iso_file_name
  url                = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.iso"
  checksum           = var.talos_iso_sha256
  checksum_algorithm = "sha256"
  overwrite          = false
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.talos_nodes

  name        = each.key
  description = "Talos Kubernetes control-plane and workload node managed by Terraform"
  tags        = ["kubernetes", "talos", "terraform"]
  node_name   = each.value.proxmox_node
  vm_id       = each.value.vm_id

  started             = true
  on_boot             = true
  protection          = var.vm_protection
  reboot_after_update = false
  stop_on_destroy     = true

  agent {
    enabled = true

    wait_for_ip {
      disabled = true
    }
  }

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["scsi0", "ide2"]

  cpu {
    cores   = var.vm_cpu_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
    floating  = 0
  }

  efi_disk {
    datastore_id      = var.vm_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    cache        = "none"
    discard      = "on"
    file_format  = "raw"
    iothread     = true
    ssd          = true
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso[each.key].id
    interface = "ide2"
  }

  network_device {
    bridge      = var.network_bridge
    mac_address = each.value.mac_address
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  startup {
    order      = "1"
    up_delay   = "30"
    down_delay = "30"
  }
}
