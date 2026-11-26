# Atuin MCP

OpenCode runs Atuin's built-in stdio MCP server as a subprocess inside its
container. Atuin config and history live under the persistent OpenCode home;
no Atuin credentials are placed in the image or OpenCode environment.

The OpenCode image is pinned to `registry.lajas.tech/opencode:0.0.15`. Sign in
to the existing Atuin account and sync history from the running pod:

```bash
kubectl -n opencode exec -it deploy/opencode -c app -- atuin login -u <username>
kubectl -n opencode exec -it deploy/opencode -c app -- atuin setup --only --daemon
kubectl -n opencode exec -it deploy/opencode -c app -- atuin sync
```

Atuin prompts for the account password and encryption key; enter them at the
prompts, not in command arguments or Kubernetes environment variables. The
daemon keeps history synced in the background. Atuin output capture is
machine-local and does not sync, so it is unavailable in this pod.

Atuin keeps a local history database and account key under the persistent home.
OpenCode can access both, so protect the home volume and its backups as
sensitive data.
