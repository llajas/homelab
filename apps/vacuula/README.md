# Vacuula

This chart deploys the Vacuula server for Neato Gen3 and Gen4 robot vacuum
cleaners. Argo CD discovers it through the repository's `apps/*` ApplicationSet.

The workload uses host networking, matching Vacuula's upstream Docker Compose
deployment. This is required for mDNS discovery and exposes the robot protocols
directly on the selected Kubernetes node:

| Port | Protocol | Purpose |
| --- | --- | --- |
| `335` | TCP | Gen3 robot connections |
| `3443` | TCP | Gen4 robot connections |
| `8050` | TCP/HTTP | Web application, API, and installer |

Only one replica can run on a node because these host ports are exclusive. The
Deployment therefore uses the `Recreate` strategy. Vacuula's database, maps,
certificates, and logs persist on a retained Longhorn claim mounted at
`/server/data`.

The web interface is available at `https://vacuula.lajas.tech` through the
cluster's public Gateway. Robot traffic does not pass through the Gateway; use
mDNS discovery or the selected node's LAN address when configuring a robot.
