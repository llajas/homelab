# mcp-woodpecker

Deploys `ghcr.io/rtuszik/woodpecker-mcp` as an HTTP MCP service connected to
`https://ci.lajas.tech` and exposes it through `mcp-woodpecker.lajas.tech` on
the public gateway. OpenCode sends the
Woodpecker token in the MCP request's `Authorization` header; the workload does
not receive `WOODPECKER_TOKEN`.

The MCP server is configured with write access (`WOODPECKER_MCP_READ_ONLY=false`).
OpenCode's Woodpecker token should therefore be scoped to the minimum permissions
needed, and the public endpoint should only be used with a client that sends an
authorized request.

Hermes can connect in-cluster at
`http://mcp-woodpecker.mcp-woodpecker.svc.cluster.local:8000/mcp`. The MCP
NetworkPolicy allows the public Gateway and Hermes Agent to reach the service.
