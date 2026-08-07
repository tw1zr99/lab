# Terraform and Proxmox

This root module creates three Talos VMs, one on each Proxmox node. Every VM is
a Kubernetes control-plane, etcd, and workload node.

## Authentication

The provider uses a Proxmox API token from the environment. Do not put the token
in Terraform files or `terraform/terraform.tfvars`.

Create a dedicated Proxmox account and role from a Proxmox root shell:

```sh
pveum user add terraform@pve
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Use Sys.Audit Sys.Modify VM.Allocate VM.Audit VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve provider --privsep 0
```

Verify that the user and token exist in the same realm before using Terraform:

```sh
pveum user list
pveum user token list terraform@pve
pveum acl list
```

`terraform@pve` is a Proxmox VE realm account, not a Linux PAM account. The
user ID, realm, and token ID must exactly match the `full-tokenid` returned by
`pveum`.

Export the complete token returned by the final command:

```sh
export PROXMOX_VE_API_TOKEN='terraform@pve!provider=TOKEN_SECRET'
```

The current Proxmox API uses its private cluster CA. Copy
`/etc/pve/pve-root-ca.pem` from a Proxmox node to the workstation and install it
in the workstation's system trust store. The endpoint certificate must include
`hades.lan` as a subject alternative name. TLS verification is enabled by
default; use `proxmox_insecure = true` only as a temporary bootstrap override.

## Workflow

```sh
task terraform:plan
```

Never apply a saved plan without reviewing it. Applying is intentionally not
part of any repository automation.

## State safety

Terraform state is currently local and ignored by Git. The active state tracks
the three Talos VMs with IDs 200 through 202 and their downloaded ISO resources.
Keep that state backed up securely; a fresh clone does not contain it.

For a complete rebuild where those VMs and ISO resources no longer exist, a
new state can create them from scratch. If any managed resources still exist,
restore the matching state or import them before applying. Never apply a plan
that proposes duplicate or replacement infrastructure without understanding
why the state and Proxmox inventory differ.

Do not store guest credentials in `terraform/terraform.tfvars`; Talos does not use
cloud-init or guest passwords.

## Talos bootstrap

The Talos ISO is downloaded directly to the `local` datastore on each Proxmox
node. Each VM boots its empty `scsi0` disk first and falls back to the ISO,
entering Talos maintenance mode. DHCP reservations should map the MAC addresses
in `talos_nodes` to the documented node IPs. Machine configuration and etcd
bootstrap are handled from the repository root with `talhelper` and `task`.
