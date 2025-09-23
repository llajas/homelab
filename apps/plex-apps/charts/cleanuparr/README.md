# cleanuparr Helm Chart

This Helm chart deploys the cleanuparr application.

## Persistent Storage

By default, persistent storage is enabled for configuration data. A PersistentVolumeClaim (PVC) will be created and mounted at `/config` in the container.

### Configuration

In `values.yaml`:

```yaml
persistentVolume:
  enabled: true                # Enable/disable persistent storage
  accessMode: ReadWriteOnce    # PVC access mode
  size: 1Gi                    # PVC size
  storageClassName: ""         # Optional storage class
  annotations: {}              # Optional PVC annotations
  existingClaim: ""            # Use an existing PVC instead of creating one
```

- If `existingClaim` is set, the chart will use the specified PVC instead of creating a new one.
- If `enabled` is `false`, no PVC will be mounted.

## Example

To use an existing PVC:

```yaml
persistentVolume:
  enabled: true
  existingClaim: my-config-pvc
```

To disable persistent storage:

```yaml
persistentVolume:
  enabled: false
```
