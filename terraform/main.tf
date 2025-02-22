resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-01"
  desc        = "master nodes"
  target_node = var.proxmox_host
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
  ipconfig0 = "ip=192.168.5.20/24,gw=192.168.5.1"

  serial {
    id   = 0
    type = "socket"
  }

  ciuser     = "root"
  cipassword = "root"
  # sshkeys = <EOF
  # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5cBlfBxMG/fUQJZzrgshvsR27KhqcUse3g+Wp2M9XJ
  # EOF
}
