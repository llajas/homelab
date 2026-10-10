# mcp-kubernetes

Deploys the Kubernetes MCP server inside the cluster as a private, read-only service for the OpenCode server and optional local access through `kubectl port-forward`.

This chart intentionally follows the repo's normal `apps/*` pattern so additional MCP servers can be added as sibling apps later instead of forcing an umbrella chart too early.

Most workload configuration is passed through under the upstream subchart key `kubernetes-mcp-server`.

The default access model is deliberately private:

- no external route by default (`HTTPRoute` disabled)
- in-cluster access is limited to the OpenCode pod by `NetworkPolicy`
- local access uses `kubectl port-forward`, authorized by the caller's kubeconfig
- read-only MCP server mode
- no upstream `config` toolset, so clients cannot request kubeconfig inspection
- a dedicated ServiceAccount supplies in-cluster credentials and cluster-wide read-only RBAC
- Secrets are denied by both Kubernetes RBAC and MCP resource filtering

Recommended local workflow:

```bash
kubectl -n mcp-kubernetes port-forward svc/mcp-kubernetes 8080:8080
```

Then point your MCP client at:

- `http://127.0.0.1:8080/mcp`

The OpenCode server connects internally to:

- `http://mcp-kubernetes.mcp-kubernetes.svc.cluster.local:8080/mcp`

If you later decide to expose it through the cluster gateway, re-enable `httpRoute.enabled` and explicitly add the gateway workload to `networkPolicy.allowedClients`.
