# Documentation

## Start Here

- [Cluster bootstrap](bootstrap.md) - build the platform from empty Proxmox VMs.
- [Architecture](architecture.md) - understand the cluster, networking, storage,
  ingress, authentication, and repository layout.
- [Cluster configuration](configuration.md) - manage shared topology, generated
  files, and local credentials.

## Platform Layers

- [Proxmox](proxmox.md) - hosts, API authentication, TLS, and networking.
- [Terraform](terraform.md) - VM provisioning, commands, variables, and state.
- [Talos](talos.md) - machine configuration, encrypted cluster secrets, and
  lifecycle operations.
- [Kubernetes](kubernetes.md) - Flux ownership, dependencies,
  pruning safety, and the component migration plan.
- [Secret operations](secrets.md) - inspect, edit, validate, and reconcile
  SOPS-encrypted Kubernetes Secrets.

## Cluster Services

- [MetalLB](architecture.md#metallb) - Layer 2 service address advertisement.
- [Traefik](architecture.md#traefik) - ingress and HTTPS routing.
- [cert-manager](architecture.md#cert-manager) - certificate issuance.
- [Authelia](architecture.md#authelia) - forward authentication and OIDC.
- [Longhorn](architecture.md#longhorn) - replicated persistent storage.
- [SOPS](architecture.md#sops) - encrypted secrets for Talos and Flux.
