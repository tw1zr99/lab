variable "ssh_key" {
  default = "your_public_ssh_key_here"
}

variable "proxmox_host" {
  default = "hades"
}

variable "template_name" {
  default = "ubuntu-2404-template"
}

variable "nic_name" {
  default = "vmbr0"
}

variable "vlan_num" {
  default = ""
}

variable "api_url" {
  default = "https://hades.lan:8006/api2/json"
}

# Blank vars for use by terraform.tfvars
# variable "token_secret" {
# }
#
# variable "token_id" {
# }
