# Disaster Recovery & Backup Plan

While not a resilient backup plan, Longhorn is configured to backup to a CIFS location. This CIFS location is monitored by a BackBlaze agent which is on the Computer Backup plan. This has a version history of 30 days that can be drawn upon.

Configuration for the backup can be seen below:

!!! example

    ```yaml title="system/longhorn-system/templates/backup.yaml"
    --8<--
    system/longhorn-system/templates/backup.yaml
    --8<--
    ```

Future implementations may include a different approach using Minio.
