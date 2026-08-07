# Homelab

> A reproducible, GitOps-managed Kubernetes platform running across three
> Proxmox hosts.

| Layer | Stack |
| --- | --- |
| Virtualization | Proxmox VE and Terraform |
| Operating system | Talos Linux |
| Orchestration | Kubernetes and FluxCD |
| Networking | MetalLB and Traefik |
| Platform | cert-manager, Authelia, Longhorn, SOPS |

## Quick Start

```sh
task preflight
task validate
task terraform:plan
terraform -chdir=terraform apply tfplan
task bootstrap
```

Terraform apply is intentionally manual and must only run after reviewing the
saved plan.

## Documentation

[Documentation index](docs/README.md) | [Bootstrap guide](docs/bootstrap.md) |
[Architecture](docs/architecture.md) | [GitOps structure](docs/gitops-structure.md)

Run `task --list` to see all provisioning, validation, and verification tasks.
