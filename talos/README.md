# Talos layer

Declarative OS + Kubernetes for three VMs distributed across the Proxmox
cluster, managed with
[talhelper](https://budimanjojo.github.io/talhelper/). Git is the source of
truth; nothing is configured by hand on the nodes.

## Files

- `talconfig.yaml` — cluster + per-node definition matching the VM IPs, disks,
  MAC addresses, control-plane VIP, and Image Factory extensions.
- `patches/longhorn.yaml` — `rshared` bind mount for `/var/lib/longhorn`.
- `talsecret.sops.yaml` — cluster PKI/secrets, **committed only SOPS-encrypted**.
- `clusterconfig/` — rendered machine configs + `talosconfig`. Git-ignored
  (plaintext secrets); regenerate any time with `task talos:genconfig`.

## Before first apply

1. Create the three VMs with Terraform after reviewing the saved plan.
2. Reserve the configured MAC addresses as `.21`, `.22`, and `.23` in DHCP so
   the maintenance ISO is reachable before static machine config is applied.
3. Confirm `/dev/sda` with `talosctl -n <ip> disks --insecure`.
4. Apply machine configuration and bootstrap Talos from the workstation.

## Storage decision (why this shape)

- Media stays on the NAS (`scale.lan`) over NFS — never on local block.
- Application config/state lives on **Longhorn at replica 2**, so a
  single node loss fails over automatically (3 nodes = no spare rebuild target
  until the dead node returns, which is the accepted trade-off at this size).
- restic → `nfs://scale.lan/.../backups` remains the disaster safety net.
