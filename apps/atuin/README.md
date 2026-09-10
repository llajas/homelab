# Atuin

This chart deploys the Atuin synchronization server and PostgreSQL. Argo CD
automatically discovers it through the repository's `apps/*` ApplicationSet.

Create a 1Password item named `atuin` in the configured vault with these fields:

| Field | Value |
| --- | --- |
| `ATUIN_DB_USERNAME` | `atuin` |
| `ATUIN_DB_PASSWORD` | A strong URI-safe password, such as `openssl rand -hex 32` |
| `ATUIN_DB_URI` | `postgres://atuin:<same password>@atuin-postgresql:5432/atuin` |

`ATUIN_DB_URI` is assembled from the username and password in the same item;
it is not supplied by Atuin or PostgreSQL. The hostname `atuin-postgresql` is
the in-cluster PostgreSQL Service created by this chart. If the password contains
characters outside letters and numbers, percent-encode it in the URI. A
hexadecimal password avoids that requirement.

The 1Password operator creates the `atuin-secrets` Kubernetes Secret. The route
serves `https://atuin.lajas.tech` through the LAN gateway. ExternalDNS creates a
DNS-only Cloudflare record targeting that gateway, while Cloudflared explicitly
rejects the hostname before its wildcard tunnel route.

## Server configuration

The chart uses the environment-variable configuration described by Atuin rather
than writing `server.toml`:

| Atuin setting | Chart value |
| --- | --- |
| `db_uri` | `ATUIN_DB_URI` from `atuin-secrets` |
| `host` | `ATUIN_HOST=0.0.0.0` |
| `port` | `ATUIN_PORT=8888` |
| `open_registration` | `ATUIN_OPEN_REGISTRATION=true` |
| `path` | `ATUIN_PATH=""` |

PostgreSQL is persistent and is only exposed inside the cluster. The Atuin
service is also a `ClusterIP`; TLS is terminated by the Cilium Gateway. There is
no HTTP listener route for this hostname, so credentials cannot be submitted to
Atuin over plaintext HTTP.

Open registration is enabled for initial account creation. After all intended
users have registered, change `ATUIN_OPEN_REGISTRATION` in `values.yaml` to
`"false"`.

Configure each Atuin client with:

```toml
sync_address = "https://atuin.lajas.tech"
```
