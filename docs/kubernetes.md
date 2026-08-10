# Kubernetes

This repository uses a single-cluster monorepo. Flux bootstraps from
`kubernetes/clusters/production`, while reusable manifests live under
`kubernetes/infrastructure` and `kubernetes/apps`.

## Target layout

```text
kubernetes/
├── clusters/production/
│   ├── flux-system/
│   ├── infrastructure.yaml
│   └── apps.yaml
├── infrastructure/
│   ├── namespaces/
│   ├── cert-manager/
│   ├── reflector/
│   ├── metallb/
│   ├── metallb-config/
│   ├── traefik/
│   ├── longhorn/
│   ├── monitoring/
│   ├── certificates/
│   ├── authelia/
│   └── routes/
├── backups/
│   └── <application>/
└── apps/
    └── <application>/
```

Each infrastructure component and application is an independent Flux
`Kustomization`. This isolates failures and pruning while retaining explicit
dependencies for CRDs, networking, and storage.

## Dependency order

1. Namespaces
2. cert-manager, Reflector, MetalLB, and Longhorn controllers
3. MetalLB configuration
4. Traefik
5. Certificates and monitoring
6. Authelia
7. Infrastructure routes and user applications

Application Kustomizations depend on Traefik when they contain an
`IngressRoute`, and on Longhorn when they contain a Longhorn PVC. Runtime
references to Authelia middleware and TLS Secrets are not hard dependencies;
those resources recover when authentication and certificate services become
available.

## Safety policy

- Namespaces, PersistentVolumes, and PersistentVolumeClaims carry
  `kustomize.toolkit.fluxcd.io/prune: disabled`.
- New Flux Kustomizations use `deletionPolicy: Orphan` so deleting a
  Kustomization does not delete its inventory.
- Normal non-persistent resources retain `prune: true`.
- Resource `apiVersion`, `kind`, `metadata.name`, and `metadata.namespace` must
  not change during a directory ownership migration.
- Existing PVC `volumeName`, `storageClassName`, and capacity fields must not
  change during the migration.

## Migration phases

The ownership migration must be delivered through separate merges. Flux may
skip intermediate Git commits, so do not squash these phases into one merge.

### Phase 1: protect state

Add prune-disable annotations to managed namespaces, PVs, and PVCs. Encrypt any
plaintext Secret manifests. Reconcile the existing broad Kustomizations and
verify all claims remain bound.

### Phase 2: orphan old inventories

Set the existing `infrastructure-controllers`, `infrastructure-configs`, and
`apps` Kustomizations to:

```yaml
spec:
  prune: false
  deletionPolicy: Orphan
  suspend: true
```

Wait until those fields are present on the live Kustomization objects.

### Phase 3: install suspended owners

Move manifests into the target layout, remove the three old Kustomization
objects, and add the new Kustomizations with `suspend: true`. Confirm the old
objects are gone and all workloads, Helm releases, namespaces, PVs, and PVCs
retain their UIDs and bindings.

### Phase 4: activate infrastructure

Unsuspend namespaces and controllers first. Then activate MetalLB configuration,
Traefik, certificates, monitoring, Authelia, and infrastructure routes according
to the dependency order.

### Phase 5: activate applications

Unsuspend the independent application Kustomizations. Verify Flux readiness,
pod health, ingress, and storage bindings before considering the migration
complete.

## Validation

Render every path before merging:

```sh
kubectl kustomize kubernetes/infrastructure/<component>
kubectl kustomize kubernetes/apps/<application>
```

After each migration phase reaches `master`:

```sh
flux reconcile source git flux-system
flux get kustomizations --all-namespaces
kubectl get pvc --all-namespaces
kubectl get pv
```
