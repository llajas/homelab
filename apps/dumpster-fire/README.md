# Dumpster Fire controller

This Argo CD-discovered app deploys the standalone controller and its internal
`dumpster-fire.dumpster-fire.svc.cluster.local:8080` status Service. The Deployment defaults to zero replicas and
`AUSTIN_FIRE_ENABLED=false`; it cannot take control until an explicit cutover.
It uses `Recreate` and one retained Longhorn claim because the controller owns
one durable state file and must remain a single writer.

The 1Password operator syncs item `m6xfspsmb26pvptji2mem7bivu` as the
`dumpster-fire-api` Secret. The item needs these exact text fields:

| Field | Value |
| --- | --- |
| `host` | ESP32 stable LAN address or pod-resolvable hostname |
| `api-key` | Existing ESPHome native API encryption key (Noise PSK) |

Do not set replicas or `AUSTIN_FIRE_ENABLED` until the old HA automations have
been disabled and the poller's state has been copied into this chart's retained
PVC. The safe activation values are one replica and `AUSTIN_FIRE_ENABLED:
"true"`. Home Assistant continues to display the controller's health and
incident metadata using the status Service; it must not regain control logic.

The image is built and pushed by the dumpster-fire repository's Woodpecker
pipeline to `registry.lajas.tech/dumpster-fire-controller`. Before activating,
follow `docs/controller-migration.md` in that repository to disable the HA
controller, transfer its durable incident state, set this chart's replicas to
one, and enable the controller. Never run two controllers against the toggle.

Validate with:

```sh
helm dependency update apps/dumpster-fire
helm lint apps/dumpster-fire
helm template dumpster-fire apps/dumpster-fire --namespace dumpster-fire
```
