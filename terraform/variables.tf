variable "proxmox_insecure" {
  description = "Disable TLS certificate validation for the Proxmox certificate."
  type        = bool
  default     = false
}

variable "vm_protection" {
  description = "Enable the Proxmox protection flag on Talos VMs."
  type        = bool
  default     = true
}
