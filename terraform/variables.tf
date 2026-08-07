variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint. Do not append /api2/json."
  type        = string
  default     = "https://hades.lan:8006/"
}

variable "proxmox_insecure" {
  description = "Disable TLS certificate validation for the self-signed Proxmox certificate."
  type        = bool
  default     = false
}

variable "talos_version" {
  description = "Talos Linux release used for the boot ISO."
  type        = string
  default     = "v1.13.8"
}

variable "talos_iso_sha256" {
  description = "SHA-256 checksum for the Talos metal AMD64 ISO."
  type        = string
  default     = "138138bb8a8b52cea250d53120b708dafc29a70ce2f7145789d9a05cf40bb2d9"
}

variable "iso_datastore_id" {
  description = "Proxmox datastore used for ISO images on each node."
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Proxmox datastore used for VM and EFI disks on each node."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox bridge connected to the Kubernetes node network."
  type        = string
  default     = "vmbr0"
}

variable "vm_cpu_cores" {
  description = "CPU cores assigned to each Talos VM."
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "Dedicated memory assigned to each Talos VM."
  type        = number
  default     = 8192
}

variable "vm_disk_size_gb" {
  description = "System and Longhorn disk size assigned to each Talos VM."
  type        = number
  default     = 100
}

variable "vm_protection" {
  description = "Enable the Proxmox protection flag on Talos VMs."
  type        = bool
  default     = true
}

variable "talos_nodes" {
  description = "Talos VM placement and stable network identity."
  type = map(object({
    proxmox_node = string
    vm_id        = number
    ip_address   = string
    mac_address  = string
  }))

  default = {
    talos-control-01 = {
      proxmox_node = "hades"
      vm_id        = 200
      ip_address   = "192.168.5.21/24"
      mac_address  = "02:00:00:05:00:21"
    }
    talos-control-02 = {
      proxmox_node = "atlas"
      vm_id        = 201
      ip_address   = "192.168.5.22/24"
      mac_address  = "02:00:00:05:00:22"
    }
    talos-control-03 = {
      proxmox_node = "venus"
      vm_id        = 202
      ip_address   = "192.168.5.23/24"
      mac_address  = "02:00:00:05:00:23"
    }
  }
}
