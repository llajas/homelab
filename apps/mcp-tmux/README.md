# mcp-tmux

Runs the stdio-only `@bnomei/tmux-mcp-rs` npm distribution behind the upstream
MCP chart's Supergateway proxy. The endpoint is private and available at
`http://mcp-tmux.mcp-tmux.svc.cluster.local:8080/mcp` using stateful Streamable
HTTP. A single replica is required because Supergateway keeps MCP sessions in
pod memory.

The workload reuses the existing `Tmux SSH Key` and `OpenCode Server`
1Password items. SSH host keys are pinned from the `known_hosts` field and
OpenSSH strict checking is enabled. The gateway's API key is sourced from the
existing `OPENCODE_API_KEY` field. Rotating that value affects both OpenCode
server authentication and this MCP endpoint; use a dedicated 1Password item if
those credentials need independent rotation.

The tmux MCP server's runtime policy exposes only `@read` tools. Cilium permits
ingress only from the OpenCode and Hermes Agent pods, and egress only for DNS,
the pinned SSH target, and npm/GitHub package downloads. OpenCode and Hermes
send the API key independently from their own runtime configuration.
OpenShell can be added later as another authenticated HTTP client by allowing
its pod identity in Cilium and configuring the same Streamable HTTP endpoint;
it is not required by this deployment.

The upstream chart is pinned as an OCI Helm dependency at
`oci://ghcr.io/javdet/charts`, version `0.6.0`. Helm fetches it while building
dependencies during Argo CD manifest generation. To update it, change the
dependency version, run `helm dependency update apps/mcp-tmux`, and render the
chart before syncing Argo CD.

The initial deployment targets `red@mt-silver.johto.lajas.tech`, matching the
existing OpenCode tmux configuration. The target needs tmux 3.0+ and a
non-interactive SSH account. The container uses the existing OpenCode image
because it already includes Node/npm and OpenSSH; the npm wrapper downloads and
checksum-verifies the tmux MCP binary at startup.

Validate with:

```bash
helm dependency build apps/mcp-tmux
helm lint apps/mcp-tmux
helm template mcp-tmux apps/mcp-tmux --namespace mcp-tmux
```
