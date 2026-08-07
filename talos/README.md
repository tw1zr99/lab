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
2. Reserve the configured MAC addresses as `.120`, `.121`, and `.122` in DHCP
   so the maintenance ISO is reachable before static machine config is applied.
3. Confirm `/dev/sda` with `talosctl -n <ip> get disks --insecure`.
4. Apply machine configuration and bootstrap Talos from the workstation.

## Requirements

- `talosctl` `v1.13.8`
- `talhelper` `v3.1.16` or newer (Talos `v1.13.8` schema support)
- `go-task`, `sops`, and `age`
- The age private identity exported as `SOPS_AGE_KEY` from the ignored `.envrc`

Talhelper does not expose a version command. For Go-built packages, inspect its
embedded module version with:

```sh
go version -m "$(command -v talhelper)"
```

## First bootstrap

Run these commands from the repository root:

```sh
task talos:validate
task talos:secret
task talos:genconfig
task talos:bootstrap
```

`talos:secret` runs only when `talos/talsecret.sops.yaml` does not exist. It
generates the cluster PKI once and encrypts it with the age recipient in
`.sops.yaml`. Commit only the encrypted `talsecret.sops.yaml`; never commit the
generated `clusterconfig/` directory.

`talos:genconfig` decrypts the SOPS file in memory and renders one machine
configuration per node plus `talosconfig` under the ignored `clusterconfig/`
directory. `talos:bootstrap` applies those configurations with `--insecure`,
waits up to five minutes for the post-install reboot, bootstraps etcd once,
writes `kubeconfig` at the repository root, and waits for cluster health.

To inspect the generated Talos commands without executing them:

```sh
cd talos
talhelper gencommand apply --extra-flags "--insecure"
talhelper gencommand bootstrap
talhelper gencommand kubeconfig --extra-flags "../ --force"
```

For later declarative machine-configuration changes, keep the existing
encrypted secrets and run:

```sh
task talos:genconfig
task talos:apply
```

Do not run `task talos:secret` to rotate credentials. Credential rotation needs
a separate, planned procedure.

## Storage decision (why this shape)

- Media stays on the NAS (`scale.lan`) over NFS — never on local block.
- Application config/state lives on **Longhorn at replica 2**, so a
  single node loss fails over automatically (3 nodes = no spare rebuild target
  until the dead node returns, which is the accepted trade-off at this size).
- restic → `nfs://scale.lan/.../backups` remains the disaster safety net.
