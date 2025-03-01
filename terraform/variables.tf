variable "ciuser" {
}

variable "cipassword" {
}

variable "ssh_key" {
  default = <<EOF
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5cBlfBxMG/fUQJZzrgshvsR27KhqcUse3g+Wp2M9XJ
  EOF
}

