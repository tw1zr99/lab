variable "venus_k3s_masters" {
  description = "List of Kubernetes master nodes for venus"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "k3s-master-04"
      ip   = "192.168.5.23/24"
    }
  ]
}

variable "venus_k3s_workers" {
  description = "List of Kubernetes worker nodes for venus"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "k3s-worker-04"
      ip   = "192.168.5.33/24"
    },
    {
      name = "k3s-worker-05"
      ip   = "192.168.5.34/24"
    }
  ]
}

resource "proxmox_vm_qemu" "k3s_master_venus" {
  count       = length(var.venus_k3s_masters)
  name        = var.venus_k3s_masters[count.index].name
  desc        = "Kubernetes master node for venus"
  target_node = "venus"
  clone       = "ubuntu-template-venus"
  agent       = 1
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu_type    = "host"
  memory      = 1024
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
          size    = 15
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
  ipconfig0 = "ip=${var.venus_k3s_masters[count.index].ip},gw=192.168.5.1"

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

resource "proxmox_vm_qemu" "k3s_worker_venus" {
  count       = length(var.venus_k3s_workers)
  name        = var.venus_k3s_workers[count.index].name
  desc        = "Kubernetes worker node for venus"
  target_node = "venus"
  clone       = "ubuntu-template-venus"
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
          size    = 15
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
  ipconfig0 = "ip=${var.venus_k3s_workers[count.index].ip},gw=192.168.5.1"

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
