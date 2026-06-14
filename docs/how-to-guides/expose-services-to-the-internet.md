# Expose services to the internet

!!! info

    This tutorial is for Cloudflare Tunnel users, please skip if you use port forwarding.

Apply the `./external` layer to create a tunnel if you haven't already,
then publish public hostnames through the Gateway API `HTTPRoute` annotations
(replace `example.com` with your domain):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/target: "homelab-tunnel.example.com"
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
# ...
```

The ExternalDNS annotations create the public DNS record, for example
`app.example.com -> homelab-tunnel.example.com`. Cloudflared is a separate hop:
the tunnel config should forward tunneled hostnames to the public Gateway
Service, and Gateway API hostname matching then selects the correct `HTTPRoute`.

For normal HTTP applications, point the `HTTPRoute` backend at a `ClusterIP`
Service:

```yaml
spec:
  parentRefs:
    - name: public-gateway
      namespace: kube-system
      sectionName: https
  hostnames:
    - app.example.com
  rules:
    - backendRefs:
        - kind: Service
          name: app-web
          port: 80
```

Do not use a direct `LoadBalancer` Service as an `HTTPRoute` backend. This is
especially important with Cilium Gateway when that Service uses
`externalTrafficPolicy: Local`, because the Gateway path can report
`no healthy upstream` even though the direct LoadBalancer path works.

If an application also needs direct non-Gateway access, split it into two
Services:

- a `ClusterIP` Service for the `HTTPRoute` backend; and
- a separate `LoadBalancer` Service for direct clients.

ClusterPlex follows this pattern:

- `plex.lajas.tech` publishes through ExternalDNS to
  `homelab-tunnel.lajas.tech`, reaches cloudflared, then enters the public
  Gateway and routes to `clusterplex-pms-web:32400`.
- `pleks.lajas.tech` is the optional direct Plex name for the separate
  `clusterplex-pms` LoadBalancer on `10.138.0.228:32400`, where
  `externalTrafficPolicy: Local` preserves client IPs.

Keep the Gateway VIP and direct application VIPs separate. In the production
cluster, `10.138.0.226` belongs to `kube-system/public-gateway`; direct Plex
access remains on `10.138.0.228`.
