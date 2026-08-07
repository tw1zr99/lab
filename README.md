# Homelab

> A reproducible, GitOps-managed Kubernetes platform running across three
> Proxmox hosts.

| Layer | Stack |
| --- | --- |
| Virtualization | Proxmox VE |
| Provisioning | Terraform |
| Operating system | Talos Linux |
| Orchestration | Kubernetes and FluxCD |
| Load balancing | MetalLB |
| Ingress | Traefik |
| Certificates | cert-manager |
| Authentication | Authelia |
| Storage | Longhorn and NFS |
| Secrets | SOPS and Age |

## Quick Start

```sh
task preflight
task validate
task terraform:plan
terraform -chdir=terraform apply tfplan
task bootstrap
```

## Documentation

[Documentation index](docs/index.md) | [Bootstrap guide](docs/bootstrap.md) |
[Architecture](docs/architecture.md) | [Configuration](docs/configuration.md) |
[Kubernetes](docs/kubernetes.md)

Run `task --list` to see all provisioning, validation, and verification tasks.
