# Proxmox

The cluster runs one Talos VM on each Proxmox host:

| Host | VM | Address | VM ID |
| --- | --- | --- | --- |
| `hades` | `talos-control-01` | `192.168.5.120` | `200` |
| `atlas` | `talos-control-02` | `192.168.5.121` | `201` |
| `venus` | `talos-control-03` | `192.168.5.122` | `202` |

Terraform connects to `https://hades.lan:8006/` and uses the `local` datastore
for ISO images, `local-lvm` for VM disks, and `vmbr0` for networking.

## API Account

Create the Terraform account, role, ACL, and token from a Proxmox root shell:

```sh
pveum user add terraform@pve
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Use Sys.Audit Sys.Modify VM.Allocate VM.Audit VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve provider --privsep 0
```

Verify the account and token:

```sh
pveum user list
pveum user token list terraform@pve
pveum acl list
```

`terraform@pve` is a Proxmox VE realm account, not a Linux PAM account. The
user, realm, and token ID must match the `full-tokenid` returned by Proxmox.

Export the token through the ignored `.envrc`:

```sh
export PROXMOX_VE_API_TOKEN='terraform@pve!provider=TOKEN_SECRET'
```

## TLS

The Proxmox API uses the cluster CA. Copy `/etc/pve/pve-root-ca.pem` from a
Proxmox node to the workstation trust store. The API certificate must include
`hades.lan` as a subject alternative name.

`TF_VAR_proxmox_insecure=true` disables provider certificate verification when
needed.

## Network Prerequisites

- Reserve the three VM MAC addresses from `terraform/variables.tf` in DHCP.
- Reserve `192.168.5.99` for the Talos Kubernetes API VIP.
- Reserve `192.168.5.50` for the MetalLB and Traefik service VIP.
- Permit node-to-node traffic on the LAN.

Terraform details and commands are documented in [terraform.md](terraform.md).
