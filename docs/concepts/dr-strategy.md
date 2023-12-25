# Disaster Recovery & Backup Plan

While not a resilient backup plan, Longhorn is configured to backup to a CIFS location. This CIFS location is monitored by a BackBlaze agent which is on the Computer Backup plan. This has a version history of 30 days that can be drawn upon.

Configuration for the backup can be seen below:

!!! example

    ```yaml
    apiVersion: longhorn.io/v1beta2
    kind: Setting
    metadata:
      name: backup-target
    value: smb-server.default.svc.cluster.local/share
    ---
    apiVersion: longhorn.io/v1beta2
    kind: Setting
    metadata:
      name: backup-target-credential-secret
    value: longhorn-backup-creds
    ```

Future implementations may include a different approach using Minio.
