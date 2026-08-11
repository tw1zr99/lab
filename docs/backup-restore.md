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
- Every application PVC using the Longhorn storage class has a separate Restic
  repository below the bucket prefix `volsync/<pvc-name>`.
- The bucket-scoped B2 key and unique per-repository passwords are maintained in
  the single SOPS-encrypted `kubernetes/backup-credentials/secret.yaml` catalog.
  Flux substitutes them into the runtime repository Secrets after the credential
  Kustomization is ready.
- The B2 bucket is private, uses the `eu-central-003` S3 endpoint, has Object
  Lock disabled, and expires noncurrent B2 object versions after one day.
  Restic independently controls snapshot retention.
- Daily backups are staggered between 00:00 and 02:20 UTC. Every repository
  retains 7 daily, 4 weekly, 6 monthly, and 1 yearly snapshot.
- Longhorn CSI clones provide crash-consistent point-in-time images. They do not
  quiesce application databases; service-specific restore checks remain part of
  recovery validation.

| UTC | PVC |
| --- | --- |
| 00:00 | `meilisearch-data` |
| 00:20 | `karakeep-data` |
| 00:40 | `filebrowser-quantum-config` |
| 01:00 | `qbittorrent-data` |
| 01:20 | `jellyfin-data` |
| 01:40 | `prowlarr-data` |
| 02:00 | `sonarr-data` |
| 02:20 | `radarr-data` |

Static NFS claims are not copied by VolSync. Their data remains on the external
TrueNAS datasets when Terraform replaces the Talos VMs.

The operator-generated Prometheus and Alertmanager PVCs are intentionally not
included. A full VM rebuild loses up to three days of metrics history and active
Alertmanager state; application data and configuration remain protected.

## Add a Protected PVC

Adding an application does not require another encrypted Secret file or a
Taskfile change:

1. Add a unique `RESTIC_PASSWORD_<PVC_NAME>` value to
   `kubernetes/backup-credentials/secret.yaml` with `sops`.
2. Add a labeled runtime Secret template with its unique B2 prefix and workload
   annotation to `kubernetes/backups/repositories.yaml`.
3. Add its scheduled `ReplicationSource` to
   `kubernetes/backups/policies.yaml`.
4. Add its production `ReplicationDestination` to
   `kubernetes/recovery/destinations.yaml`.
5. Increment `spec.postBuild.substitute.CATALOG_VERSION` on both the
   `backup-credentials` and `backups` Flux Kustomizations.
6. Run `task kubernetes:validate` and merge the change.

The VolSync tasks discover protected PVCs and workload mappings from the
rendered repository Secrets. VolSync initializes a new Restic repository during
its first backup. The matching catalog-version labels prevent repository
templates from reconciling against credentials from an older Git revision.

The Age identity used by SOPS must be backed up separately from the cluster and
the B2 repository. Without it, a rebuilt cluster cannot decrypt the Restic
password even when the repository itself survives.

## Run and Verify Backups

Run every backup sequentially before destructive maintenance:

```sh
task volsync:backup
```

The task waits for a successful mover result for each PVC, attempts to restore
every daily schedule on exit, and prints a `RESTORE_AS_OF` cutoff. If Flux is
unreachable during cleanup, follow the printed instruction to resume or
reconcile `backups` manually. Record the exact cutoff with the maintenance
notes. It prevents a newly bootstrapped empty PVC or a later empty snapshot from
superseding the known-good backups.

## Test an Isolated Restore

Run an isolated transport-level restore drill for every repository:

```sh
task volsync:verify
```

The task restores repositories sequentially into isolated temporary Longhorn
PVCs, verifies the Restic transport and mover result, and deletes each test PVC
after success. Set `VERIFY_AS_OF=<cutoff>` to exercise the exact snapshots
selected for disaster recovery. A failure leaves its isolated resources
available for investigation and never mounts or changes a production claim.

The Karakeep-specific fixture additionally checks expected application files.
It always targets a new PVC and never mounts or changes the live
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

`terraform destroy` deletes the Talos VM disks and all Longhorn replicas. A
normal `task bootstrap` recreates applications with empty Longhorn PVCs; it does
not restore data. Use `bootstrap:restore` instead.

Immediately before a planned rebuild, create snapshots, save the cutoff printed
by the command, and run isolated transport-level restores against that cutoff:

```sh
task volsync:backup
VERIFY_AS_OF=2026-08-10T20:00:00Z task volsync:verify
terraform -chdir=terraform destroy
task terraform:plan
terraform -chdir=terraform apply tfplan
CONFIRM_RESTORE=restore-production \
  RESTORE_AS_OF=2026-08-10T20:00:00Z \
  task bootstrap:restore
```

Replace the example timestamp with the exact value printed by
`task volsync:backup`. For an unplanned loss, choose a UTC cutoff after the last
known-good scheduled backup and before the replacement cluster began writing
empty data.

The guarded restore performs these operations:

1. Bootstraps Talos, Kubernetes, and Flux, then immediately suspends the `apps`
   and `backups` Kustomizations while their infrastructure dependencies install.
2. Installs Longhorn, the snapshot controller, and VolSync, then creates only
   the static PVs, empty PVCs, and decrypted repository Secrets.
3. Confirms every production PVC and encrypted repository Secret exists.
4. Scales any stateful application Deployment that won the suspension race to
   zero and removes only the managed scheduled
   `ReplicationSource` resources.
5. Restores the most recent snapshot at or before `RESTORE_AS_OF` into each
   canonical production PVC.
6. Resumes applications and scheduled backups only after all eight mover results
   are `Successful`.

The restore overwrites all files on the managed Longhorn PVCs. A mover failure
does not trigger an automatic resume or rollback. A later Flux reconciliation
failure can occur after one or both Kustomizations have been resumed, so always
inspect actual suspension and workload state before rerunning the command.
Inspect the failed `ReplicationDestination`, mover Job, and Pod as applicable:

```sh
kubectl get replicationdestinations,jobs,pods --namespace default
kubectl describe replicationdestination <pvc-name> --namespace default
kubectl logs job/<mover-job> --namespace default
```

After recovery, verify convergence and workload status. Application-level data
checks remain service-specific; the Karakeep fixture demonstrates one such
check:

```sh
task cluster:verify
flux get kustomizations
kubectl get replicationsources --namespace default
kubectl get pvc --namespace default
kubectl get deployments --namespace default
```

Backblaze credentials provide access to every repository prefix in the bucket.
Use only a bucket-scoped application key and rotate it if the cluster is
compromised.
