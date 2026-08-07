# Cluster Configuration

`config/cluster.yaml` is the source of truth for non-secret cluster topology and
shared settings.

It defines:

- Cluster name, domain, versions, API address, and Git source.
- Gateway, DNS, ingress address, trusted LAN, and network bridge.
- Proxmox endpoint, datastores, VM sizing, and Talos ISO checksum.
- External storage, router, DNS, and Proxmox host endpoints.
- Talos node names, Proxmox placement, VM IDs, addresses, and MAC addresses.

## Consumers

Terraform reads `config/cluster.yaml` directly with `yamldecode`.

Talhelper loads it through its native `--env-file` support and substitutes the
values in `talos/talconfig.yaml`.

The Taskfile reads individual values with `yq` for Flux bootstrap, Talos
maintenance commands, and HTTPS verification.

`task config:render` generates
`kubernetes/clusters/production/cluster-vars.yaml` with `yq`.

Flux Kustomizations use `cluster-vars` for post-build substitution across
controllers, infrastructure configuration, and applications.

## Commands

After changing `config/cluster.yaml`:

```sh
task config:render
task validate
```

`task config:check` verifies that the generated Flux ConfigMap matches the
canonical configuration.

## Credentials

Credentials and workstation-specific paths remain in the ignored `.envrc`.
`.envrc.example` documents the required variable names. Kubernetes and Talos
secret data remains SOPS-encrypted in Git, while `.envrc` supplies the Age
identity used to decrypt it.
