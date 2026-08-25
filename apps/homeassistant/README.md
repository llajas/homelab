# home-assistant

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![AppVersion: 2026.8.2](https://img.shields.io/badge/AppVersion-2026.8.2-informational?style=flat-square)

Home Assistant

This chart deploys Home Assistant with native chart templates in this repository. It owns `configuration.yaml`, keeps the
existing `/config` PVC, uses Gateway API `HTTPRoute`, and preserves the Matter sidecar and monitoring resources used in
this homelab.

## Source Code

* <https://github.com/home-assistant/home-assistant>
* <https://github.com/pajikos/home-assistant-helm-chart>

## Requirements

Kubernetes: supported by the cluster Gateway API and monitoring CRDs used in this repo.

## Installing the Chart

To install the chart with the release name `homeassistant`

```console
helm install homeassistant . --namespace homeassistant
```

## Uninstalling the Chart

To uninstall the `homeassistant` deployment

```console
helm uninstall homeassistant --namespace homeassistant
```

The command removes the Helm release resources. The existing `/config` PVC is retained by the dedicated
`templates/config-pvc.yaml` manifest and its `helm.sh/resource-policy: keep` annotation.

## Configuration

Read through the [values.yaml](./values.yaml) file. This chart is configured directly from top-level values rather than a
subchart-specific schema.

## Custom configuration

### Managed `configuration.yaml`

This chart owns Home Assistant's `configuration.yaml` through `configuration.templateConfig` and an init container that
writes or merges the managed config into the existing `/config` volume.

`configuration.forceInit: true` is enabled in the current values so each start merges the existing live file with the
Helm-managed template, creating timestamped backups and keeping only the 10 most recent backups.

### Gateway API / reverse proxy handling

When `httpRoute.enabled: true`, the managed `configuration.yaml` includes:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.69.0.0/16
    - 192.168.42.0/24
    - 127.0.0.0/8
```

The chart also requires `httpRoute.parentRefs` to be set and will fail rendering if it is empty.

### HTTPRoute

The current values render:

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: kube-system
      sectionName: https
  hostnames:
    - home-assistant.lajas.tech
```

This chart renders both:

- the main HTTPS `HTTPRoute`
- an HTTP redirect route that sends traffic to HTTPS with `301`

### Persistence

This chart preserves the current Home Assistant config volume by binding the Deployment to the existing claim:

```yaml
controller:
  type: Deployment

persistence:
  enabled: true
  existingClaim: homeassistant-home-assistant-config
  accessMode: ReadWriteOnce
  size: 1Gi
  storageClass: longhorn
```

Matter state is preserved separately on the existing `homeassistant` PVC mounted at `/data`.

### Matter

This chart runs the Matter server as a sidecar container in the same pod as Home Assistant. The Matter server listens on
port `5580` and stores its Matter fabric data on a dedicated persistent volume mounted at `/data`.

After deploying the chart, add the Matter integration in Home Assistant and use the following server URL when prompted for
an existing Matter server:

```text
ws://127.0.0.1:5580/ws
```

### Metrics collection

If metrics collection is enabled through `serviceMonitor.enabled: true`, the managed `configuration.yaml` also includes the
Home Assistant `prometheus:` block and the chart renders both a `ServiceMonitor` and the `HomeAssistantAbsent`
`PrometheusRule`.

### Recorder retention

Recorder retention is managed directly in the owned `configuration.yaml` template:

```yaml
recorder:
  purge_keep_days: 365
  auto_purge: true
  auto_repack: true
```

Home Assistant keeps detailed recorder history for `purge_keep_days`, while long-term statistics for eligible sensors may
remain available beyond that window as hourly aggregates.

## Values

Most workload settings live in `values.yaml` at the top level.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.tag` | string | `"2026.8.2"` | Home Assistant container version |
| `controller.type` | string | `"Deployment"` | Deployment controller used so the chart can bind the existing `/config` PVC by claim name |
| `persistence.existingClaim` | string | `"homeassistant-home-assistant-config"` | Existing PVC mounted at `/config` |
| `matter.persistence.existingClaim` | string | `"homeassistant"` | Existing PVC mounted at `/data` for Matter |
| `configuration.enabled` | bool | `true` | Enables managed `configuration.yaml` |
| `configuration.forceInit` | bool | `true` | Merges managed config into the live `configuration.yaml` on startup |
| `httpRoute.enabled` | bool | `true` | Enables Gateway API routing |
| `httpRoute.parentRefs` | list | See values.yaml | Required Gateway attachment refs |
| `serviceMonitor.enabled` | bool | `true` | Enables Prometheus scraping resources |
| `metrics.prometheusRule.enabled` | bool | `true` | Enables the absence alert |

## Support

- See the [Home Assistant documentation](https://www.home-assistant.io/docs/)
- See the [Home Assistant Container installation guide](https://www.home-assistant.io/installation/linux#install-home-assistant-container)

----------------------------------------------
Maintained as part of this homelab repository.
