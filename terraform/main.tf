locals {
  cluster = yamldecode(file("${path.module}/../config/cluster.yaml"))
  talos_nodes = {
    (local.cluster.NODE_1_NAME) = {
      proxmox_node = local.cluster.NODE_1_PROXMOX_HOST
      vm_id        = tonumber(local.cluster.NODE_1_VM_ID)
      ip_address   = "${local.cluster.NODE_1_ADDRESS}/${local.cluster.NETWORK_PREFIX_LENGTH}"
      mac_address  = local.cluster.NODE_1_MAC_ADDRESS
    }
    (local.cluster.NODE_2_NAME) = {
      proxmox_node = local.cluster.NODE_2_PROXMOX_HOST
      vm_id        = tonumber(local.cluster.NODE_2_VM_ID)
      ip_address   = "${local.cluster.NODE_2_ADDRESS}/${local.cluster.NETWORK_PREFIX_LENGTH}"
      mac_address  = local.cluster.NODE_2_MAC_ADDRESS
    }
    (local.cluster.NODE_3_NAME) = {
      proxmox_node = local.cluster.NODE_3_PROXMOX_HOST
      vm_id        = tonumber(local.cluster.NODE_3_VM_ID)
      ip_address   = "${local.cluster.NODE_3_ADDRESS}/${local.cluster.NETWORK_PREFIX_LENGTH}"
      mac_address  = local.cluster.NODE_3_MAC_ADDRESS
    }
  }
  talos_iso_file_name = "talos-${trimprefix(local.cluster.TALOS_VERSION, "v")}-metal-amd64.iso"
}

resource "proxmox_download_file" "talos_iso" {
  for_each = local.talos_nodes

  content_type       = "iso"
  datastore_id       = local.cluster.PROXMOX_ISO_DATASTORE
  node_name          = each.value.proxmox_node
  file_name          = local.talos_iso_file_name
  url                = "https://github.com/siderolabs/talos/releases/download/${local.cluster.TALOS_VERSION}/metal-amd64.iso"
  checksum           = local.cluster.TALOS_ISO_SHA256
  checksum_algorithm = "sha256"
  overwrite          = false
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_nodes

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
    cores   = tonumber(local.cluster.VM_CPU_CORES)
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = tonumber(local.cluster.VM_MEMORY_MB)
    floating  = 0
  }

  efi_disk {
    datastore_id      = local.cluster.PROXMOX_VM_DATASTORE
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = local.cluster.PROXMOX_VM_DATASTORE
    interface    = "scsi0"
    size         = tonumber(local.cluster.VM_DISK_SIZE_GB)
    cache        = "none"
    discard      = "on"
    file_format  = "raw"
    ssd          = true
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso[each.key].id
    interface = "ide2"
  }

  network_device {
    bridge      = local.cluster.NETWORK_BRIDGE
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
