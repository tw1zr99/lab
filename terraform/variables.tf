variable "ciuser" {
}

variable "cipassword" {
}

variable "ssh_key" {
  default = <<EOF
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5cBlfBxMG/fUQJZzrgshvsR27KhqcUse3g+Wp2M9XJ
  EOF
}

variable "k3s_masters" {
  description = "List of Kubernetes master nodes"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "k3s-master-01"
      ip   = "192.168.5.20/24"
    },
    {
      name = "k3s-master-02"
      ip   = "192.168.5.21/24"
    }
  ]
}

variable "k3s_workers" {
  description = "List of Kubernetes worker nodes"
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "k3s-worker-01"
      ip   = "192.168.5.30/24"
    }
  ]
}
