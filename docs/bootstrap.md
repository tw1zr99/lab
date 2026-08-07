# Cluster bootstrap (from scratch)

Rebuilds the cluster onto three Talos VMs distributed across the Proxmox hosts.
After an approved Terraform apply has booted the VMs into maintenance mode:

```sh
task talos:secret     # once, ever — generates + SOPS-encrypts cluster secrets
task bootstrap        # Talos cluster, then Flux takes over from git
```

`task bootstrap` runs two phases:

1. **Talos** (`talos:bootstrap`) — renders machine configs, applies them to all
   three nodes, bootstraps etcd, and writes `./kubeconfig`.
2. **Flux** (`flux:bootstrap`) — creates the `sops-age` decryption secret, then
   `flux bootstrap git` installs Flux and points it at
   `kubernetes/clusters/production`. Flux reconciles everything else:
   controllers (Longhorn, Traefik, cert-manager, Authelia, monitoring), configs,
   and apps.

## Provision the VMs

Terraform is intentionally separate from `task bootstrap` so VM changes cannot
be applied implicitly:

```sh
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Only run `terraform apply tfplan` after the plan has been reviewed and the
change has been explicitly approved.

No physical console is needed for the Talos VMs. Terraform downloads and
attaches the Talos ISO, configures a Proxmox serial console, and starts each VM.
The maintenance environment must receive its reserved address from DHCP before
the static Talos machine configuration can be applied remotely.

## Prerequisites (workstation)

`talosctl` `v1.13.8`, `talhelper` `v3.1.16` or newer, `sops`, `age`, `kubectl`,
`flux`, `go-task`, and `direnv`. Talhelper `v3.1.16` is the first release in
this workflow with explicit Talos `v1.13.8` schema support.
Set the age private identity directly in the ignored `.envrc` as
`SOPS_AGE_KEY`. The recipient public key lives in `age.pub` / `.sops.yaml`.

Create the ignored `.envrc` from `.envrc.example`, set the Proxmox token and
local key paths, then authorize it with `direnv allow`. Flux requires
`FLUX_SSH_KEY_PATH` to reference an SSH private key with write access to the Git
repository. `KUBECONFIG` points direct `kubectl` and `flux` commands at the
repository-local kubeconfig generated during Talos bootstrap.

## Preflight

- Configure Proxmox API token authentication as documented in
  `terraform/README.md`.
- Reserve the VM MAC addresses from `terraform/variables.tf` in DHCP.
- Confirm that `.10` is free for the API VIP and `.120` through `.122` are free
  for the nodes.
- Confirm that Talos sees the Terraform `scsi0` disk as `/dev/sda`.

## Validate without applying

```sh
task talos:validate
task talos:genconfig                              # render machine configs
kubectl kustomize kubernetes/clusters/production  # render Flux entrypoint
```

## Notes carried over from the migration

- **Storage:** media on NFS (`scale.lan`); config/state on Longhorn **replica 2**.
- **Talos vs k3s gotchas already handled:** `iscsi-tools` + `util-linux-tools`
  extensions for Longhorn, `rshared` mount for `/var/lib/longhorn`, and the
  `pod-security.kubernetes.io/enforce: privileged` label on `longhorn-system`
  (Talos enforces PodSecurity; k3s did not).
- **Optional follow-up:** move disposable volumes (e.g. Prometheus TSDB) off
  Longhorn onto a node-local provisioner. On Talos this needs a writable path
  under `/var` — left out of the core scaffold until the chart/path are pinned.
