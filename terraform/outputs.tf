output "talos_nodes" {
  description = "Talos VM placement and stable network identities."
  value = {
    for name, node in local.talos_nodes : name => {
      proxmox_node = node.proxmox_node
      vm_id        = node.vm_id
      ip_address   = node.ip_address
      mac_address  = node.mac_address
    }
  }
}
