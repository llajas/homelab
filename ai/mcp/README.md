# MCP Helm Chart

A universal Helm chart for deploying [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) servers on Kubernetes. Supports two deployment modes: **direct** for MCP servers with native HTTP transport, and **proxy** for stdio-only servers wrapped by an HTTP gateway.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/mcp-helm-chart)](https://artifacthub.io/packages/search?repo=mcp-helm-chart)

## TL;DR

```bash
helm install my-mcp oci://ghcr.io/javdet/charts/mcp --version 0.6.0 -f values.yaml
```

Or install from a local clone:

```bash
git clone https://github.com/javdet/mcp-helm-chart.git
helm install my-mcp ./mcp-helm-chart -f values.yaml
```

## Introduction

Many MCP servers only speak stdio and cannot be deployed as long-running HTTP services. This chart solves that problem by offering two modes:

| Mode | When to use | How it works |
|------|-------------|--------------|
| `direct` | The MCP server image already supports HTTP/SSE (e.g. `grafana/mcp-grafana`) | Deploys the image as-is with optional `command`/`args` overrides |
| `proxy` | The MCP server is stdio-only (e.g. `@digitalocean/mcp`, `kubernetes-mcp-server`) | Runs a Node.js container with [supergateway](https://github.com/supercorp-ai/supergateway) that wraps the stdio command into Streamable HTTP, SSE or WebSocket |

## Prerequisites

- Kubernetes >= 1.21
- Helm >= 3.8 (OCI registry support)

## Installing the Chart

```bash
helm install my-mcp oci://ghcr.io/javdet/charts/mcp \
  --version 0.6.0 \
  --namespace mcp \
  --create-namespace \
  -f values.yaml
```

To list available versions:

```bash
helm show all oci://ghcr.io/javdet/charts/mcp
```

## Uninstalling the Chart

```bash
helm uninstall my-mcp --namespace mcp
```

## Examples

### Direct mode — Grafana MCP server

```yaml
mode: direct

image:
  repository: grafana/mcp-grafana
  tag: "v0.4.0"

containerPort: 8080

args:
  - "-t"
  - "streamable-http"
  - "--address"
  - "0.0.0.0:8080"

env:
  - name: GRAFANA_URL
    value: "https://grafana.example.com"

secret:
  enabled: true
  data:
    GRAFANA_SERVICE_ACCOUNT_TOKEN: "glsa_..."
```

### Proxy mode — DigitalOcean MCP server (stdio)

```yaml
mode: proxy

containerPort: 8080

proxy:
  gateway:
    stdioCommand: "npx -y @digitalocean/mcp --services apps,droplets,doks,networking"
    outputTransport: streamableHttp
    port: 8080
    httpPath: /mcp

secret:
  enabled: true
  data:
    DIGITALOCEAN_API_TOKEN: "dop_v1_..."
```

### Proxy mode — Kubernetes MCP server (stdio)

```yaml
mode: proxy

containerPort: 8080

proxy:
  gateway:
    stdioCommand: "npx -y kubernetes-mcp-server@latest"

volumes:
  - name: kubeconfig
    secret:
      secretName: kubeconfig-secret

volumeMounts:
  - name: kubeconfig
    mountPath: /root/.kube/config
    readOnly: true
```

## Parameters

### Deployment mode

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | Deployment mode: `direct` or `proxy` | `direct` |

### Common parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of pod replicas | `1` |
| `containerPort` | Port the MCP server listens on inside the container | `8080` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full release name | `""` |

### Direct mode image configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `""` |
| `image.tag` | Container image tag (immutable tags are recommended) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Registry credentials for private images | `[]` |
| `command` | Override the container entrypoint | `[]` |
| `args` | Override the container arguments | `[]` |

### Proxy mode configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `proxy.image.repository` | Proxy container image repository | `node` |
| `proxy.image.tag` | Proxy container image tag | `20-slim` |
| `proxy.image.pullPolicy` | Proxy image pull policy | `IfNotPresent` |
| `proxy.gateway.package` | NPM package used as the HTTP gateway (pin a version, e.g. `supergateway@3.4.3`, for reproducible rollouts) | `supergateway` |
| `proxy.gateway.stdioCommand` | The stdio MCP command to wrap (required in proxy mode) | `""` |
| `proxy.gateway.outputTransport` | Transport exposed by the gateway: `streamableHttp`, `sse` or `ws` | `streamableHttp` |
| `proxy.gateway.port` | Port the gateway listens on (should match `containerPort`) | `8080` |
| `proxy.gateway.httpPath` | MCP endpoint path — `--streamableHttpPath` for `streamableHttp`, `--ssePath` for `sse` | `/mcp` |
| `proxy.gateway.messagePath` | Path clients POST messages to (`sse` and `ws` only) | `/message` |
| `proxy.gateway.baseUrl` | Public base URL advertised to SSE clients (`sse` only) | `""` |
| `proxy.gateway.stateful` | Keep MCP sessions in memory (`streamableHttp` only) | `false` |
| `proxy.gateway.sessionTimeout` | Session timeout in milliseconds (stateful `streamableHttp` only) | `""` |
| `proxy.gateway.logLevel` | Gateway log level: `debug`, `info` or `none` | `info` |
| `proxy.gateway.healthEndpoints` | Extra paths that return `ok`, usable by probes | `[]` |
| `proxy.gateway.cors.enabled` | Enable CORS on the gateway | `false` |
| `proxy.gateway.cors.origins` | Allowed origins; empty means all (`*`). Wrap in slashes for a regex | `[]` |
| `proxy.gateway.extraArgs` | Additional supergateway CLI arguments | `[]` |

### Environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env` | Extra environment variables injected into the container | `[]` |
| `envFrom` | Extra `envFrom` sources (configMapRef, secretRef) | `[]` |

### Secret

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.enabled` | Create a Secret resource and mount it via `envFrom` | `false` |
| `secret.annotations` | Annotations added to the Secret | `{}` |
| `secret.data` | Key-value pairs stored as `stringData` in the Secret | `{}` |

### Secrets injection (External Secrets vs Vault)

Choose **one** way to supply credentials to the workload:

| Mode | When to use |
|------|-------------|
| **Inline Secret** (`secret.enabled`) | Simple manifests; keys live in Helm values (not for production secrets). |
| **External Secrets Operator** (`externalSecrets.enabled`) | You run [ESO](https://external-secrets.io/) and a `SecretStore` / `ClusterSecretStore`; the chart creates an `ExternalSecret` and mounts the synced Kubernetes `Secret` via `envFrom`. |
| **Banzai Cloud Vault webhook** (`vault.enabled`) | Your cluster uses the Vault mutating webhook; the chart adds `vault.security.banzaicloud.io/*` pod annotations. |

**Rules:**

- `externalSecrets.enabled` and `vault.enabled` are **mutually exclusive**; Helm fails if both are true.
- With ESO, keep `secret.enabled` **false** unless `externalSecrets.target.name` points at a **different** Secret name than the chart fullname (otherwise two writers would target the same Secret).

### External Secrets Operator

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Create an `ExternalSecret` and mount its target `Secret` | `false` |
| `externalSecrets.apiVersion` | `external-secrets.io` API version (`v1` or `v1beta1`) | `external-secrets.io/v1` |
| `externalSecrets.refreshInterval` | ESO refresh interval | `1h` |
| `externalSecrets.secretStoreRef.name` | `SecretStore` / `ClusterSecretStore` name (required if enabled) | `""` |
| `externalSecrets.secretStoreRef.kind` | Store kind | `ClusterSecretStore` |
| `externalSecrets.target.name` | Kubernetes `Secret` to sync into (default: chart fullname) | `""` |
| `externalSecrets.target.creationPolicy` | ESO `creationPolicy` | `Owner` |
| `externalSecrets.annotations` | Annotations on the `ExternalSecret` | `{}` |
| `externalSecrets.labels` | Extra labels on the `ExternalSecret` | `{}` |
| `externalSecrets.data` | `spec.data` entries | `[]` |
| `externalSecrets.dataFrom` | `spec.dataFrom` entries | `[]` |

Example (sync one remote secret by key; mount as env via `envFrom`):

```yaml
secret:
  enabled: false

externalSecrets:
  enabled: true
  secretStoreRef:
    name: my-cluster-store
    kind: ClusterSecretStore
  dataFrom:
    - extract:
        key: path/to/remote-secret
```

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Service port (maps to `containerPort` on the pod) | `80` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable Ingress resource creation | `false` |
| `ingress.className` | IngressClass name | `""` |
| `ingress.annotations` | Annotations for the Ingress resource | `{}` |
| `ingress.hosts` | Ingress host rules | `[]` |
| `ingress.tls` | TLS configuration for the Ingress | `[]` |

### Gateway API (HTTPRoute)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gatewayApi.enabled` | Enable HTTPRoute resource creation | `false` |
| `gatewayApi.annotations` | Annotations for the HTTPRoute resource | `{}` |
| `gatewayApi.parentRefs` | References to the parent Gateway resource(s) | `[]` |
| `gatewayApi.hostnames` | Hostnames matched by this HTTPRoute | `[]` |
| `gatewayApi.timeouts` | Default timeouts applied to all rules | `{}` |
| `gatewayApi.rules` | Routing rules (backendRefs defaults to chart service if omitted) | `[]` |

### Gateway API Authentication (Envoy SecurityPolicy)

Creates a `gateway.envoy.io/v1alpha1` SecurityPolicy targeting the HTTPRoute. Supports JWT validation and API key authentication.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gatewayApi.auth.type` | Authentication type: `jwt`, `apiKey`, or `""` (disabled) | `""` |
| `gatewayApi.auth.annotations` | Annotations for the SecurityPolicy resource | `{}` |
| `gatewayApi.auth.jwt.providers` | List of JWT providers (used when `auth.type=jwt`) | `[]` |
| `gatewayApi.auth.apiKey.extractFrom` | Headers from which to extract the API key (used when `auth.type=apiKey`) | Authorization Bearer |
| `gatewayApi.auth.apiKey.credentialRefs` | References to Secrets holding valid API keys | `[]` |

### ServiceAccount

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a ServiceAccount resource | `true` |
| `serviceAccount.name` | Override ServiceAccount name (defaults to fullname) | `""` |
| `serviceAccount.annotations` | Annotations added to the ServiceAccount | `{}` |
| `serviceAccount.automountServiceAccountToken` | Mount the API token into pods | `true` |

### Resource management

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/memory resource requests and limits | `{}` |

### Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `probes.livenessProbe` | Liveness probe configuration | tcpSocket on port `http` |
| `probes.readinessProbe` | Readiness probe configuration | tcpSocket on port `http` |

### Volumes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes` | Extra volumes to add to the pod | `[]` |
| `volumeMounts` | Extra volume mounts for the container | `[]` |

### Pod scheduling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

### HashiCorp Vault (Banzai Cloud webhook)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vault.enabled` | Add Vault webhook annotations on pods | `false` |
| `vault.role` | Vault role used for Kubernetes authentication | `""` |
| `vault.path` | Vault auth backend mount path | `""` |

### Pod metadata & security

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Annotations added to each pod | `{}` |
| `podLabels` | Extra labels added to each pod | `{}` |
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context | `{}` |

## Gateway API Authentication

When using the Gateway API with Envoy Gateway, you can protect your MCP servers with a `SecurityPolicy`. The chart supports two authentication modes.

### JWT validation

```yaml
gatewayApi:
  enabled: true
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - mcp.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
  auth:
    type: jwt
    jwt:
      providers:
        - name: mcp-static-tokens
          issuer: "https://theinfranod.com"
          audiences:
            - "mcp-servers"
          localJWKS:
            type: ValueRef
            valueRef:
              group: ""
              kind: ConfigMap
              name: jwks-config
```

### API key authentication

```yaml
gatewayApi:
  enabled: true
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - mcp.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
  auth:
    type: apiKey
    apiKey:
      extractFrom:
        headers:
          - name: Authorization
            valuePrefix: "Bearer "
      credentialRefs:
        - group: ""
          kind: Secret
          name: mcp-api-keys
```

## How Proxy Mode Works

In proxy mode the chart launches a `node:20-slim` container and runs:

```
npx -y supergateway \
  --stdio '<your stdioCommand>' \
  --outputTransport streamableHttp \
  --port 8080 \
  --streamableHttpPath '/mcp' \
  --logLevel info
```

The gateway spawns the stdio MCP server as a child process, translates stdio messages to/from HTTP, and exposes a Streamable HTTP endpoint that any MCP client can connect to.

Additional flags are appended from the values above: `--stateful`/`--sessionTimeout` for session-bound servers,
`--healthEndpoint` for probe targets, `--cors` for browser clients, and anything in `proxy.gateway.extraArgs`.

### Health probes in proxy mode

`supergateway` has no health endpoint by default, so the chart's probes fall back to `tcpSocket`. To probe over
HTTP instead, register an endpoint and point the probes at it. Values are merged with the chart defaults, so set
`tcpSocket: null` as well — otherwise the probe ends up with two handlers and the API server rejects it:

```yaml
proxy:
  gateway:
    healthEndpoints:
      - /healthz

probes:
  livenessProbe:
    tcpSocket: null
    httpGet:
      path: /healthz
      port: http
  readinessProbe:
    tcpSocket: null
    httpGet:
      path: /healthz
      port: http
```

### Stateful sessions

Servers that keep state between requests need `proxy.gateway.stateful: true`. Sessions live in the pod's memory,
so with `replicaCount` above 1 the ingress or Gateway must pin a session to one pod, otherwise follow-up requests
land on a pod that does not know the session.

## Migrating from 0.5.x

Releases up to 0.5.1 used `@michlyn/mcpgateway`, which is no longer actively maintained. 0.6.0 switches the
default to [supergateway](https://github.com/supercorp-ai/supergateway). If you did not override
`proxy.gateway.package`, no values change is required — `outputTransport: streamable-http` is still accepted and
normalized to `streamableHttp`. Two things to check:

- `proxy.gateway.httpPath` is now rendered as `--streamableHttpPath` (or `--ssePath`) instead of `--httpPath`.
  The default `/mcp` endpoint is unchanged.
- If you pinned `proxy.gateway.package` to `@michlyn/mcpgateway`, remove the override, or keep it and also set
  `proxy.gateway.extraArgs` accordingly — the two packages do not share a CLI.

## License

This project is licensed under the MIT License.
