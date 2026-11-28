# Telemetry

This Argo CD-discovered chart deploys the telemetry API in the `telemetry`
namespace. Argo CD creates the namespace automatically. The workload stays at
one replica and uses the immutable image digest built from telemetry commit
`407d92f`.

## Private access

The HTTPRoute attaches to the shared `public-gateway` HTTPS listener and sends
only `/api/v1/` to the ClusterIP Service. It is excluded from Cloudflare
ExternalDNS while the internal DNS controllers can publish the private Gateway
address. The Cloudflare Tunnel wildcard route has a preceding `http_status:404`
rule for `telemetry.lajas.tech`, so the hostname cannot fall through to the
wildcard tunnel route.

The UniFi certificate is valid for `unifi-atx.lajas.tech`, while the controller
is at the private address `10.137.0.1`. The Pod's host alias maps the verified
hostname to that address, preserving TLS verification without routing through
Cloudflare.

## Secrets

The chart materializes two 1Password items as namespace-local Kubernetes
Secrets. `telemetry-unifi` reuses the existing read-only `unifipoller` password
item. `telemetry-api-consumer-tokens` references the separate API-token item;
its `API_CONSUMER_TOKENS` field must contain one `consumer=token` entry per
active consumer, separated by semicolons. For example, use a `cloud-key` entry
for the current Cloud Key consumer. Generate token values outside Git and keep
them only in 1Password. Environment-variable changes require a Pod restart.

## Validate and smoke-test

Before merging, render the chart:

```sh
helm dependency update apps/telemetry
helm lint apps/telemetry
helm template telemetry apps/telemetry --namespace telemetry
```

After Argo CD syncs the merged change, verify the Deployment has one ready
replica, then from an authorized private client:

- `GET https://telemetry.lajas.tech/api/v1/snapshot` returns `401` without a
  bearer token and `200` with a valid consumer token.
- The snapshot includes both the UniFi speed-test and Kubernetes summary
  resources, and both collection outcomes become `ok` after collectors run.
- `/healthz`, `/readyz`, and `/metrics` are reachable through the in-cluster
  Service, but the hostname route does not expose those paths.
- Public DNS has no A or AAAA answer for `telemetry.lajas.tech`, and the
  Cloudflare Tunnel returns 404 for that hostname.
