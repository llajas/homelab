# home-assistant

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![AppVersion: 2026.8.2](https://img.shields.io/badge/AppVersion-2026.8.2-informational?style=flat-square)

Home Assistant

This chart deploys Home Assistant Container with the bjw-s app-template chart.

## Source Code

* <https://github.com/home-assistant/home-assistant>
* <https://github.com/bjw-s-labs/helm-charts/tree/main/charts/other/app-template>

## Requirements

Kubernetes: supported by the cluster Gateway API and monitoring CRDs used in this repo.

## Dependencies

| Repository | Name | Version |
|------------|------|---------|
| https://bjw-s-labs.github.io/helm-charts | app-template | 4.4.0 |

## TL;DR

```console
helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts
helm repo update
helm install homeassistant . --namespace homeassistant
```

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

The command removes the Helm release resources. Persistent volume retention depends on the cluster storage class and reclaim policy.

## Configuration

Read through the [values.yaml](./values.yaml) file. Most workload options are under the `app-template` key and follow the bjw-s app-template values schema.

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

```console
helm install homeassistant . \
  --namespace homeassistant \
  --set app-template.controllers.main.containers.main.env.TZ="America/New_York"
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart.

```console
helm install homeassistant . --namespace homeassistant -f values.yaml
```

## Custom configuration

### HTTP 400 bad request while accessing from your browser

When configuring Home Assistant behind a reverse proxy make sure you configure the [http](https://www.home-assistant.io/integrations/http) component and set `trusted_proxies` correctly and `use_x_forwarded_for` to `true`.

For example (by edit the configuration.yaml hosted in your pod):

```yaml
http:
  server_host: 0.0.0.0
  ip_ban_enabled: true
  login_attempts_threshold: 5
  use_x_forwarded_for: true
  trusted_proxies:
  # Pod CIDR
  - 10.69.0.0/16
  # Node CIDR
  - 192.168.42.0/24
```

### Z-Wave / Zigbee

A Z-Wave and/or Zigbee controller device could be used with Home Assistant if passed through from the host to the pod. Skip this section if you are using zwave2mqtt and/or zigbee2mqtt or plan to.

First you will need to mount your Z-Wave and/or Zigbee device into the pod, you can do so by adding the following to your values:

```yaml
persistence:
  usb:
    enabled: true
    type: hostPath
    hostPath: /path/to/device
```

Second you will need to set a nodeAffinity rule, for example:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: app
          operator: In
          values:
          - zwave-controller
```

... where a node with an attached zwave and/or zigbee controller USB device is labeled with `app: zwave-controller`

### Websockets

If an ingress controller is being used with home assistant, web sockets must be enabled using annotations to enable support of web sockets.

Using NGINX as an example the following will need to be added to your values:

```yaml
ingress:
  main:
    enabled: true
    annotations:
      nginx.org/websocket-services: home-assistant
    hosts:
      - host: home-assistant.example.org
        paths:
          - path: /
```

The value derived is the name of the kubernetes service object for home-assistant

### Metrics collection

If metrics collection is enabled through the `metrics.enabled: true` setting, make sure to also enable the Prometheus
endpoint in your Home-Assistant configuration. See the [official documentation](https://www.home-assistant.io/integrations/prometheus/) for more details on how to set this up.

## Values

Most workload settings live under `app-template` and follow the bjw-s app-template values schema. Home Assistant-specific routing and alert settings are configured under `httpRoute` and `metrics`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| app-template.controllers.main.containers.main.image.tag | string | `"2026.8.2"` | Home Assistant container version |
| app-template.controllers.main.containers.main.env.TZ | string | `"America/Chicago"` | Container timezone |
| app-template.defaultPodOptions.hostNetwork | bool | `true` | Enables LAN discovery behavior expected by Home Assistant Container |
| app-template.defaultPodOptions.dnsPolicy | string | `"ClusterFirstWithHostNet"` | Required DNS policy when using host networking |
| app-template.persistence.config | object | See values.yaml | Persistent `/config` volume |
| app-template.persistence.custom-config | object | See values.yaml | ConfigMap mounted for reverse-proxy trusted proxy configuration |
| app-template.serviceMonitor.main | object | See values.yaml | Prometheus scrape config for `/api/prometheus` |
| httpRoute | object | See values.yaml | Gateway API route for `home-assistant.lajas.tech` |
| metrics.enabled | bool | `true` | Enables Home Assistant monitoring resources |
| metrics.prometheusRule.enabled | bool | `true` | Enables the absence alert |

## Changelog

### Version 0.1.0

#### Added

N/A

#### Changed

* Migrated the chart from k8s-at-home common to bjw-s app-template
* Upgraded Home Assistant to version 2026.8.2

#### Fixed

N/A

## Support

- See the [Home Assistant documentation](https://www.home-assistant.io/docs/)
- See the [Home Assistant Container installation guide](https://www.home-assistant.io/installation/linux#install-home-assistant-container)
- See the [bjw-s app-template documentation](https://bjw-s-labs.github.io/helm-charts/docs/app-template/)

----------------------------------------------
Maintained as part of this homelab repository.
