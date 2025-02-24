resource "proxmox_vm_qemu" "k3s_master" {
  count       = length(var.k3s_masters)
  name        = var.k3s_masters[count.index].name
  desc        = "Kubernetes master node"
  target_node = "hades"
  clone       = "VM 9000"
  agent       = 1
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu_type    = "host"
  memory      = 3072
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 32
          cache   = "writeback"
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot      = "order=scsi0"
  ipconfig0 = "ip=${var.k3s_masters[count.index].ip},gw=192.168.5.1"

  serial {
    id   = 0
    type = "socket"
  }

  ciuser     = "root"
  cipassword = "root"
  sshkeys    = var.ssh_key

  lifecycle {
    ignore_changes = [
      bootdisk
    ]
  }
}

resource "proxmox_vm_qemu" "k3s_worker" {
  count       = length(var.k3s_workers)
  name        = var.k3s_workers[count.index].name
  desc        = "Kubernetes worker node"
  target_node = "hades"
  clone       = "VM 9000"
  agent       = 1
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu_type    = "host"
  memory      = 3072
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 32
          cache   = "writeback"
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot      = "order=scsi0"
  ipconfig0 = "ip=${var.k3s_workers[count.index].ip},gw=192.168.5.1"

  serial {
    id   = 0
    type = "socket"
  }

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_key

  lifecycle {
    ignore_changes = [
      bootdisk
    ]
  }
}
