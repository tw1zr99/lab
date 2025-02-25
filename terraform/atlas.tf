##############################
# atlas.tf
##############################

variable "atlas_k3s_masters" {
  description = "List of Kubernetes master nodes for atlas"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "atlas-k3s-master-01"
      ip   = "192.168.5.22/24"
    }
  ]
}

variable "atlas_k3s_workers" {
  description = "List of Kubernetes worker nodes for atlas"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "atlas-k3s-worker-01"
      ip   = "192.168.5.31/24"
    },
    {
      name = "atlas-k3s-worker-02"
      ip   = "192.168.5.32/24"
    },
    {
      name = "atlas-k3s-worker-03"
      ip   = "192.168.5.33/24"
    }
  ]
}

# Deploy the Kubernetes master node on atlas
resource "proxmox_vm_qemu" "k3s_master_atlas" {
  count       = length(var.atlas_k3s_masters)
  name        = var.atlas_k3s_masters[count.index].name
  desc        = "Kubernetes master node for atlas"
  target_node = "atlas"
  clone       = "VM 9000"
  agent       = 1
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu_type    = "host"
  memory      = 4096
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
          size    = 100
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
  ipconfig0 = "ip=${var.atlas_k3s_masters[count.index].ip},gw=192.168.5.1"

  serial {
    id   = 0
    type = "socket"
  }

  # You can use the same ciuser/ssh key settings as before
  ciuser     = "root"
  cipassword = "root"
  sshkeys    = var.ssh_key

  lifecycle {
    ignore_changes = [
      bootdisk
    ]
  }
}

# Deploy the Kubernetes worker nodes on atlas
resource "proxmox_vm_qemu" "k3s_worker_atlas" {
  count       = length(var.atlas_k3s_workers)
  name        = var.atlas_k3s_workers[count.index].name
  desc        = "Kubernetes worker node for atlas"
  target_node = "atlas"
  clone       = "VM 9000"
  agent       = 1
  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  cpu_type    = "host"
  memory      = 4096
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
          size    = 100
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
  ipconfig0 = "ip=${var.atlas_k3s_workers[count.index].ip},gw=192.168.5.1"

  serial {
    id   = 0
    type = "socket"
  }

  # Use the same ciuser and cipassword as defined in your main variables
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_key

  lifecycle {
    ignore_changes = [
      bootdisk
    ]
  }
}
