# Rebooting Nodes (Kured)

Kured is modified slightly in this deployment to leverage the [`rebootSentinelCommand`](https://kured.dev/docs/configuration/#reboot-sentinel-command) that points towards a custom [reboot script](https://github.com/llajas/homelab/blob/master/metal/roles/cronjobs/files/rebooter.sh). This script is pushed to all nodes during provisioning using the built in [Ansible playbook](https://github.com/llajas/homelab/blob/3ca11bdbe2b593455a1c63b76bfdce9bda0d77fd/metal/roles/cronjobs/tasks/main.yml#L5C36-L5C36).

!!! warn
    When using `rebootSentinelCommand`, you effectively override the default setting for Kured, which checks for the existence of `sentinelFile` eg. `/var/run/reboot-required` every sixty minutes.

The aforementioned script works to provide the best of both worlds in that kured will run the `rebooter.sh` script every `5m` in which one of two things will occur:

- Check if `/var/run/reboot-required` exists.
- Run `needs-restarting --reboothint` which checks whether a full reboot is required (exit code 1) or not (exit code 0) whenever there is a package or system update.

!!! note
    See the [needs-restarting(1) — Linux manual page](https://www.man7.org/linux/man-pages/man1/needs-restarting.1.html) page for more information on the `needs-restarting` command.


## Cronjob Reboots

Reboots on individual nodes can be triggered easily on any node by running `touch /var/run/reboot-required`. You can also create a cronJob to perform this command at any set interval which will be picked up by `kured` on the next check.

## Limit reboot to specific time

By default, reboots are permitted to only occur Monday-Friday, 9PM to 5AM. Reboots will be held until this timeframe window is met to ensure that nodes do not reboot during the middle of the day. This can be configured in the `values.yaml` file.
