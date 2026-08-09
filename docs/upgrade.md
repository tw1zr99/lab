# Kubernetes Upgrade

Kubernetes upgrades are performed by Talos and are intentionally separate from
Talos OS, Flux, Helm chart, and application upgrades. The target Kubernetes
version comes only from `KUBERNETES_VERSION` in `config/cluster.yaml`.

## Requirements

- The cluster must be healthy before starting.
- The local `talosctl` version must match `TALOS_VERSION` in
  `config/cluster.yaml`.
- `talos/clusterconfig/talosconfig` and the repository-local `kubeconfig` must
  exist and provide access to all three nodes.
- `mikefarah/yq` v4, `talosctl`, `talhelper`, and `kubectl` must be installed.
- Review Kubernetes and Talos release notes for version-specific requirements.
  Upgrade one Kubernetes minor version at a time.

## Prepare

Change `KUBERNETES_VERSION` in `config/cluster.yaml`, then regenerate and
validate the derived configuration:

```sh
task config:render
task validate
```

Do not hardcode the target version in the Taskfile or Talos configuration. The
tasks remove the leading `v` only when passing the version to `talosctl`.

## Preflight and Plan

Run the health checks and inspect the live node versions:

```sh
task kubernetes:upgrade:preflight
```

Generate Talos's upgrade plan without modifying the cluster:

```sh
task kubernetes:upgrade:plan
```

The preflight checks generated configuration, Kubernetes API readiness, every
node's Ready condition, and Talos cluster health. Resolve every failure before
continuing.

## Execute

```sh
task kubernetes:upgrade
```

`talosctl upgrade-k8s` updates the control-plane components and kubelets one
node at a time. The task connects through `NODE_1_ADDRESS`, but Talos
orchestrates the upgrade across the full cluster. On this three-control-plane
cluster, expect several minutes per node. Temporary pod restarts and brief
changes in control-plane availability are normal, but quorum should remain
available throughout the serial upgrade.

The task runs the full post-upgrade verification automatically. It requires all
kubelets, API servers, controller managers, schedulers, and kube-proxy to use
the configured target version, then runs the existing cluster verification for
Talos health, Flux reconciliation, certificates, storage, MetalLB, and HTTPS.

To rerun only verification:

```sh
task kubernetes:upgrade:verify
```

## Interruption and Recovery

`talosctl upgrade-k8s` is reconciliatory and can be rerun with the same target
after a terminal disconnect, timeout, or workstation interruption. First
inspect the current state:

```sh
kubectl get nodes -o wide
kubectl get pods --namespace kube-system
task kubernetes:upgrade:plan
```

If the cluster is healthy enough to proceed, rerun:

```sh
task kubernetes:upgrade
```

Already-upgraded components remain at the target while Talos completes the
remaining work. Do not change the target version during recovery. If the API is
temporarily unavailable, use Talos directly to confirm etcd and node health:

```sh
cd talos
talhelper gencommand health --env-file ../config/cluster.yaml | bash
```

If credentials are stale, refresh generated access without rotating cluster
secrets:

```sh
task talos:genconfig
task talos:kubeconfig
```

Never regenerate `talos/talsecret.sops.yaml` as part of an upgrade.

## Final Checks

After a successful upgrade, confirm the repository contains only the intended
version and generated ConfigMap changes:

```sh
task config:check
git diff -- config/cluster.yaml kubernetes/clusters/production/cluster-vars.yaml
```

Commit those files together so Git remains the source of truth for the running
version.
