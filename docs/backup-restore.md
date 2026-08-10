# Backup and Restore

VolSync backs up selected Longhorn PVCs with Restic to Backblaze B2. Each PVC
uses a separate encrypted Restic repository prefix in the private
`tw1zr-lab-volsync` bucket and can be restored without relying on Longhorn
volume identities from the original cluster.

## Components

- VolSync is installed by the `volsync` HelmRelease in `volsync-system`.
- The CSI snapshot controller and snapshot CRDs are installed by the
  `snapshot-controller` HelmRelease, using the upstream version bundled with
  Longhorn.
- `karakeep-data` is the initial backup pilot.
- The `karakeep-data` repository is stored below the bucket prefix
  `volsync/karakeep-data` through the EU S3-compatible endpoint.
- The repository password is SOPS-encrypted in
  `kubernetes/backups/karakeep/secret.yaml`.
- Daily backups run at 03:00 UTC with daily, weekly, monthly, and yearly
  retention.

The Age identity used by SOPS must be backed up separately from the cluster and
the B2 repository. Without it, a rebuilt cluster cannot decrypt the Restic
password even when the repository itself survives.

## Trigger a Backup Test

Temporarily replace the schedule with a unique manual trigger:

```sh
kubectl patch replicationsource karakeep-data --namespace default --type merge \
  --patch '{"spec":{"trigger":{"schedule":null,"manual":"backup-test-1"}}}'
kubectl wait replicationsource karakeep-data --namespace default \
  --for=jsonpath='{.status.lastManualSync}'=backup-test-1 --timeout=20m
kubectl get replicationsource karakeep-data --namespace default -o yaml
```

Reconcile the applications afterward to restore the daily schedule:

```sh
flux reconcile kustomization backups
```

## Test an Isolated Restore

The restore test always targets a new PVC and never mounts or changes the live
`karakeep-data` claim.

Create the restore resources and wait for the latest backup to restore:

```sh
kubectl apply -f tests/volsync/karakeep-restore.yaml
kubectl wait replicationdestination karakeep-data-restore-test \
  --namespace default \
  --for=jsonpath='{.status.lastManualSync}'=restore-test-1 --timeout=20m
```

Mount the restored claim in the verification pod. It becomes Ready only when
both Karakeep SQLite files exist and are non-empty:

```sh
kubectl apply -f tests/volsync/karakeep-verify.yaml
kubectl wait pod karakeep-data-restore-test --namespace default \
  --for=condition=ready --timeout=5m
kubectl exec --namespace default karakeep-data-restore-test -- ls -lh /data
```

Delete only the isolated test resources after verification:

```sh
kubectl delete -f tests/volsync/karakeep-verify.yaml
kubectl delete -f tests/volsync/karakeep-restore.yaml
```

## Fresh Cluster Recovery

On a fresh cluster, install Longhorn and VolSync before restoring data. The
normal `backups` Kustomization depends on `apps` because its scheduled sources
need existing PVCs; it is not the restore bootstrap path. For disaster recovery,
suspend the application Kustomization, apply the required decrypted repository
Secrets, restore each repository into its target PVC, verify the data, and only
then resume the application workload.

Backblaze credentials provide access to every repository prefix in the bucket.
Use only a bucket-scoped application key and rotate it if the cluster is
compromised.
