# Terraform

Terraform provisions three Talos VMs, one on each Proxmox node. Every VM is a
Kubernetes control-plane, etcd, and workload node.

## Module

The root module is under `terraform/` and uses `bpg/proxmox` `0.111.1`.

It manages:

- The pinned Talos ISO on each Proxmox node.
- VM IDs `200`, `201`, and `202`.
- Stable VM names and MAC addresses.
- UEFI, Q35, VirtIO SCSI, fixed memory, and serial consoles.
- VM startup and boot order.

Provider authentication and Proxmox account setup are documented in
[proxmox.md](proxmox.md).

## Taskfile Workflow

```sh
task terraform:init
task terraform:validate
task terraform:plan
terraform -chdir=terraform apply tfplan
```

The equivalent direct Terraform commands are:

```sh
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

## Variables

Topology and infrastructure defaults are defined in `config/cluster.yaml`,
including:

- Proxmox endpoint, storage, and network bridge.
- Talos version and ISO checksum.
- VM CPU, memory, and disk sizing.
- Proxmox node placement, VM IDs, IP addresses, and MAC addresses.

Environment variables used by the provider are shown in `.envrc.example`.

## State

Terraform state is currently local and ignored by Git. The active state tracks
the three Talos VMs and downloaded ISO resources. A fresh clone does not contain
that state.

For a complete rebuild where the managed resources no longer exist, a new state
can create them. If the resources still exist, restore the matching state or
import them before applying.

## Talos Handoff

The VMs boot from their empty `scsi0` disk first and fall back to the Talos ISO.
DHCP reservations map their configured MAC addresses to their configured node
addresses in maintenance mode. `task bootstrap` handles machine configuration,
installation, etcd bootstrap, Kubernetes, and Flux.
