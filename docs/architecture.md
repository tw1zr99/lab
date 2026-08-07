# Architecture

This repository defines a three-node Kubernetes cluster distributed across a
three-host Proxmox environment. Every Talos VM runs control-plane, etcd, and
workload roles. Flux reconciles the cluster from Git.

## Proxmox

Proxmox VE provides the virtualization layer across `hades`, `atlas`, and
`venus`. Each host runs one Talos VM. Storage and network identifiers are
defined in `terraform/variables.tf`.

See [proxmox.md](proxmox.md) for host placement, API authentication, TLS, and
network prerequisites.

## Terraform

Terraform downloads the pinned Talos ISO and creates the VMs with stable IDs,
MAC addresses, UEFI, Q35, VirtIO SCSI, serial consoles, and fixed resources.

See [terraform.md](terraform.md) for module details, commands, variables, and
state handling.

## Talos

Talos Linux provides the immutable Kubernetes operating system. Talhelper
renders machine configuration from `talos/talconfig.yaml` using encrypted
cluster secrets from `talos/talsecret.sops.yaml`.

- Node addresses: `192.168.5.120` through `192.168.5.122`
- Kubernetes API VIP: `192.168.5.99`
- Kubernetes version: `v1.36.2`
- Talos version: `v1.13.8`

See [talos.md](talos.md) for configuration and lifecycle operations.

## Kubernetes

Flux watches `master` and reconciles `kubernetes/clusters/production`.

The current dependency chain is:

1. `infrastructure-controllers`
2. `infrastructure-configs`
3. `apps`

Controller and application manifests are rendered from
`kubernetes/infrastructure` and `kubernetes/apps`. See
[kubernetes.md](kubernetes.md) for ownership, dependencies, and pruning safety.

## MetalLB

MetalLB provides Layer 2 LoadBalancer addresses. The pool currently contains
`192.168.5.50/32`. Because every node is a control-plane node, the speaker chart
uses `ignoreExcludeLB: true`.

## Traefik

Traefik exposes HTTP and HTTPS through the MetalLB address `192.168.5.50` and
handles Kubernetes `IngressRoute` resources. The external ingress class is
`traefik-external` and TLS traffic uses the `websecure` entrypoint.

## cert-manager

cert-manager obtains the `efym.net` and `*.efym.net` certificate from Let's
Encrypt using Cloudflare DNS01 validation. The certificate is stored as
`efym-net-tls`, and Reflector copies it into application namespaces.

## Authelia

Authelia provides Traefik forward authentication and acts as an OIDC provider
for applications such as Karakeep and Jellyfin.

The shared forward-auth endpoint is:

```text
http://authelia.authelia.svc.cluster.local:9091/api/authz/forward-auth
```

## Longhorn

Longhorn provides replicated block storage for application configuration and
state. The default replica count is two. Talos includes the iSCSI and util-linux
extensions plus the shared mount required by Longhorn.

Bulk media and shared data remain on NFS exports from `scale.lan`.

## SOPS

SOPS encrypts Talos cluster secrets and Kubernetes Secret manifests with Age.
The workstation identity is supplied through `SOPS_AGE_KEY`. Flux receives the
same identity through the `sops-age` Secret in `flux-system` and decrypts
manifests during reconciliation.

Plaintext machine configuration, kubeconfig, local environment files, and
Terraform state remain outside Git.

## Repository Layout

```text
.
├── docs/                               # Documentation
├── kubernetes/
│   ├── apps/                           # Application manifests
│   ├── clusters/production/            # Flux cluster entrypoint
│   └── infrastructure/                 # Controllers and shared configuration
├── talos/                              # Talhelper source and encrypted secrets
├── terraform/                          # Proxmox VM module
├── Taskfile.yml                        # Reproducible commands
└── README.md                           # Project overview
```

Each application directory generally contains a Kustomization plus its
Deployment, Service, IngressRoute, storage, and encrypted Secret resources.

## Network Endpoints

| Endpoint | Address |
| --- | --- |
| Kubernetes API | `192.168.5.99:6443` |
| Traefik LoadBalancer | `192.168.5.50` |
| TrueNAS and NFS | `scale.lan` |
| Proxmox API | `https://hades.lan:8006/` |
