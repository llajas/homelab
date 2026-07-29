# Longhorn

## Creating Backups

Backups can be created in two ways:

### Backups via CLI

#### Create the YAML

Create a `.yaml` file with the following contents:

```yaml
apiVersion: longhorn.io/v1beta2
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: cifs://plex.lajas.tech/pvc
  credentialSecret: cifs-creds
  pollInterval: 5m0s
```

You'll want to have an existing secret that `credentialSecret` can reference.

### Backups via GUI

#### Enabling the GUI

It can be easier in most cases to troubleshoot Longhorn by enabling the GUI. This can be done by creating an [`ingress`](https://github.com/llajas/homelab/blob/master/system/longhorn-system/templates/ingress.yaml) object for the deployment where automation will take over and setup all that is necessary to access the GUI.

Navigate to the Longhorn UI, then click Setting > General > Backup

See [Set Backup Target](https://longhorn.io/docs/1.5.3/snapshots-and-backups/backup-and-restore/set-backup-target/) for further steps on how to configure Longhorn to backup to your preferred storage medium.

## Troubleshooting

### Lower available space on GPU nodes

Nodes with GPUs can show less disk space available to Longhorn than otherwise similar nodes. This does not necessarily mean Longhorn is using the disk unevenly. GPU-capable nodes often run larger workloads and keep larger container image layers, model data, cache directories, or other host-local artifacts outside of Longhorn's managed replica data.

When comparing Longhorn usage across nodes, check both the Longhorn scheduled replica data and the node's raw filesystem availability. A node can have very little Longhorn scheduled storage while still being close to Longhorn's free-space scheduling threshold because non-Longhorn data is consuming the underlying filesystem.

If this happens, prefer freeing host-local space first, such as pruning unused container images or moving non-Longhorn caches, before forcing Longhorn replica movement. Forced rebalancing can create rebuild I/O and should be treated as an intentional maintenance action.

### `disk failure/volume failed fsck check`

For issues that generate the following event:

```sh
  Warning  FailedMount  2m1s (x4 over 8m8s)  kubelet            MountVolume.MountDevice failed for volume "pvc-c548803f-4eb9-47f3-843b-c448e5d4c738" : rpc error: code = Internal desc = 'fsck' found errors on device /dev/longhorn/pvc-c548803f-4eb9-47f3-843b-c448e5d4c738 but could not correct them: fsck
```

A fix to this is to attach the volume using the GUI to a node, then accessing it as a normal block device and fixing using `fsck` using the following [GitHub commenty](https://github.com/longhorn/longhorn/issues/1911#issuecomment-734704687).

### Exclusive Attachment

You will sometimes come across this error despite having killed/scaled down any pods associated to a PVC/PV:

```sh
Multi-Attach error for volume "pvc-0122bbe5-ca54-4e73-87be-5cbe9afa691a" Volume is already exclusively attached to one node and can't be attached to another
```

Make note of the PVC and then run the following:

```sh
kubectl get volumeattachment | grep pvc-0122bbe5-ca54-4e73-87be-5cbe9afa691a
kubectl delete volumeattachment csi-f12fdf2abf305183d7eba30b4012c97a33d33dc0b61612756ec330b0f32901e7
```

This is sometimes observed when a node is shutdown without warning.
