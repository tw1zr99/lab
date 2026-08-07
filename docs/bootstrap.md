# Cluster bootstrap

This is the canonical runbook for rebuilding the production cluster from empty
Proxmox VMs. Commands run from the repository root unless stated otherwise.

Terraform provisions the VMs but is never applied by the Taskfile. After the
VMs are running in Talos maintenance mode, `task bootstrap` configures Talos,
bootstraps Kubernetes, installs Flux, and waits for GitOps convergence.

## 1. External prerequisites

The repository cannot configure these external dependencies:

- Proxmox nodes `hades`, `atlas`, and `venus` are online and use the storage and
  bridge names in `terraform/variables.tf`.
- DHCP reserves the MAC addresses in `terraform/variables.tf` as
  `192.168.5.120`, `.121`, and `.122` for Talos maintenance mode.
- `192.168.5.99` is unused and reserved for the Kubernetes API VIP.
- `192.168.5.50` is unused and reserved for the MetalLB/Traefik service VIP.
- The LAN gateway is `192.168.5.1` and permits node-to-node traffic, including
  TCP and UDP port `7946` for MetalLB speaker membership.
- `scale.lan` resolves to the TrueNAS server and the NFS exports referenced by
  the Kubernetes manifests exist.
- The Cloudflare token already encrypted in Git remains valid for DNS01
  certificate issuance.
- The workstation has the Age private identity matching `age.pub`. Without it,
  neither Talos secrets nor Kubernetes Secrets in this repository can decrypt.
- The Flux SSH key has write access to `ssh://git@github.com/tw1zr99/lab`.

For LAN access to `efym.net` and its subdomains, use one of these network
configurations:

- Configure split DNS so `efym.net` and `*.efym.net` resolve to
  `192.168.5.50` on the LAN.
- Keep public DNS and configure router hairpin NAT plus TCP ports `80` and `443`
  forwarding to `192.168.5.50`.

External access always requires public DNS and router port forwarding to
`192.168.5.50`.

## 2. Workstation setup

Install these commands:

- Terraform `>= 1.9.0`
- `talosctl` `v1.13.8`
- `talhelper` `v3.1.16` or newer
- `sops`, `age`, `kubectl`, `flux`, `go-task`, `git`, `curl`, and `direnv`

Create the ignored environment file and fill in the real values:

```sh
cp .envrc.example .envrc
direnv allow
task preflight
```

`SOPS_AGE_KEY` must contain the Age private identity directly.
`FLUX_SSH_KEY_PATH` must point to the SSH private key file. Never commit
`.envrc`, `kubeconfig`, rendered Talos machine configs, Terraform state, or a
saved Terraform plan.

Create the Proxmox account and API token using [proxmox.md](proxmox.md).
Terraform configuration and state are documented in
[terraform.md](terraform.md).

## 3. Validate the repository

Run all static checks before provisioning:

```sh
task validate
```

This initializes and validates Terraform, validates the Talhelper
configuration, and renders these actual Kustomize roots:

- `kubernetes/infrastructure/controllers`
- `kubernetes/infrastructure/configs`
- `kubernetes/apps`

`kubernetes/clusters/production` is a Flux manifest directory, not a Kustomize
root, so do not run `kubectl kustomize` against that directory.

## 4. Provision the Talos VMs

Create a saved plan:

```sh
task terraform:plan
```

Apply the saved plan with Terraform:

```sh
terraform -chdir=terraform apply tfplan
```

Terraform downloads the pinned Talos ISO on each Proxmox node and creates VM
IDs `200`, `201`, and `202`. Each VM boots its empty disk first, falls back to
the ISO, receives its reserved DHCP address, and enters maintenance mode.

Confirm all three nodes are reachable and inspect their disks:

```sh
task talos:disks
```

Do not continue if the intended system disk is not `/dev/sda`; update
`talos/talconfig.yaml` first.

## 5. Bootstrap Talos and Flux

Run the complete software bootstrap:

```sh
task bootstrap
```

The task performs these operations in order:

1. Checks tools, the Age identity, and the Flux SSH key.
2. Reuses `talos/talsecret.sops.yaml`, or creates it once if absent.
3. Renders ignored machine configs under `talos/clusterconfig`.
4. Applies the machine configs with `--insecure` to maintenance-mode nodes.
5. Waits for installation and reboot, then bootstraps etcd exactly once.
6. Writes the repository-local `kubeconfig`.
7. Waits for Talos and Kubernetes health.
8. Creates Flux's in-cluster `sops-age` Secret.
9. Bootstraps Flux against `master` at `kubernetes/clusters/production`.
10. Reconciles Git and waits for every Flux Kustomization to become ready.
11. Verifies controllers, storage, MetalLB advertisement, and HTTPS ingress.

The default Flux and Kubernetes readiness timeout is 20 minutes. Override it
for a slow first image pull:

```sh
task bootstrap BOOTSTRAP_TIMEOUT=30m
```

Do not run `task bootstrap` against an existing configured cluster because its
Talos apply phase intentionally uses `--insecure` for first installation.

## 6. Verify the result

The bootstrap runs this automatically, but it can be repeated safely:

```sh
task cluster:verify
```

For additional inspection:

```sh
kubectl get nodes -o wide
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
kubectl get pods --all-namespaces
kubectl get pvc --all-namespaces
kubectl get servicel2statuses.metallb.io --all-namespaces
curl --resolve efym.net:443:192.168.5.50 --head https://efym.net
```

Expected results:

- All three nodes are `Ready`.
- Every Flux Kustomization and HelmRelease is `Ready`.
- PersistentVolumeClaims are `Bound`.
- A MetalLB `ServiceL2Status` assigns the Traefik service to one node.
- The direct VIP HTTPS check returns `HTTP/2 200` with a valid certificate.

The service VIP is not expected to answer ICMP ping. Test TCP/HTTPS instead.

## 7. Day-two operations

After changing Talos configuration, retain the existing encrypted secrets and
apply the declarative update without `--insecure`:

```sh
task talos:genconfig
task talos:apply
task talos:kubeconfig  # required when the Kubernetes API endpoint changes
task cluster:verify
```

After pushing Kubernetes changes:

```sh
task kubernetes:validate
task flux:wait
task cluster:verify
```

List all available automation with:

```sh
task --list
```

## Recovery boundary

This process reproduces infrastructure and configuration. It does not restore
application data. Longhorn volume or application-level backup restoration is a
separate disaster-recovery operation; do not assume a fresh cluster bootstrap
recovers prior PVC contents.
