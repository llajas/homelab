# Hermes Agent

Argo CD discovers this chart through the repository's `apps/*` ApplicationSet.
It runs the Hermes Agent gateway and management dashboard at
`https://hermes-agent.lajas.tech`. The dashboard uses the homelab identity
provider's OIDC authorization-code flow with PKCE; restrict this OIDC client to
the intended users in the identity provider because Hermes' dashboard has no
user allowlist. Dashboard access grants shell-like control over the agent, so
treat the OIDC client as privileged. The chart's NetworkPolicy blocks inbound
traffic and limits egress to DNS and public services. A CiliumNetworkPolicy
allows Cilium's reserved `ingress` identity to reach dashboard port 9119 and
allows Hermes to reach only the `public-gateway` Service for Kanidm OIDC
discovery. Cilium translates the Gateway Service's HTTPS port to Envoy's
backend port before its L4 policy check, so the service rule targets port 9999.
Cilium identity/service selectors are needed because Kubernetes `ipBlock` rules
do not match Cilium-managed nodes or services by default.

The `OnePasswordItem` syncs the item UUID in `values.yaml` into the
`hermes-agent-secrets` Kubernetes Secret. For static API-key providers, add the
provider's expected key (for example `OPENAI_API_KEY`) to that 1Password item.
Do not commit API credentials.

The default configuration uses Hermes' `openai-codex` provider and enables its
OpenAI Codex device login. It does **not** use an OpenAI API key: on first start,
read the `auth-device-login` init-container logs for the verification URL and
one-time code, then approve it with the OpenAI account that has Codex access:

```bash
kubectl -n hermes-agent logs deploy/hermes-agent -c auth-device-login -f
```

The resulting refreshable login is stored on Hermes' persistent volume. The
model is set to `gpt-5.6-terra` from the upstream chart's Codex example; available
models and usage limits depend on the signed-in account. Hermes upstream does
not document which ChatGPT plan tiers are eligible or how usage counts against
the plan, so confirm available models and quota after signing in. Change
`hermes-agent.config.model` to select another model supported by that account.
`notify: logs` avoids requiring a Discord or Telegram bot just to complete
login.

The private `homelab-identity` repository is the desired-state owner for
Kanidm OAuth clients and groups; this repository cannot register the client
itself. Add a **public** OIDC client named `hermes-agent` there, using
authorization code + PKCE (S256), and restrict it to a dedicated group using
the client-specific policy pattern used for Neko. Add authorized users to that
group in `homelab-identity/users/<username>.json`, then apply the identity
repository's Terraform change before syncing this app. Register this exact
redirect URI:

```text
https://hermes-agent.lajas.tech/auth/callback
```

The issuer configured in `values.yaml` is
`https://auth.lajas.tech/oauth2/openid/hermes-agent`. The 1Password item
`homelab-kanidm-hermes-agent-oidc-client-id` creates the
`hermes-agent-oidc-client-id` Secret; the workload reads its `client_id` field
as `HERMES_DASHBOARD_OIDC_CLIENT_ID`. Hermes uses a public PKCE client, so the
dashboard OIDC flow does not need a client secret. The item's `password` field
is intentionally not mounted into the agent pod; only the `client_id` field is
used for this public-client flow. The dashboard route is TLS-only on the
cluster's `public-gateway`.

The OpenCode pay-as-you-go Console can also be used directly by Hermes, but it
uses an OpenCode Console API key, not the OpenCode browser session. Add
`OPENCODE_ZEN_API_KEY` to the same 1Password item, then switch to provider
`opencode-zen` and turn off Codex device login in `values.yaml`:

```yaml
hermes-agent:
  config:
    model:
      provider: opencode-zen
      default: <model-id-available-in-your-opencode-console>
  auth:
    deviceFlow:
      enabled: false
```

If your OpenCode plan is **Go** rather than Console credits, use provider
`opencode-go` and field `OPENCODE_GO_API_KEY`. Both paths are pay-as-you-go or
plan-limited according to the OpenCode account. A GitHub Copilot path is
available through Hermes' Copilot integration, but it cannot bypass an
exhausted Copilot allowance; wait for reset or enable additional usage per your
GitHub plan.

To use API-key billing instead, change `provider` to `openai-api`, select an
API model, and store `OPENAI_API_KEY` in the same 1Password item. The OpenAI API
is billed separately from a Codex subscription.

The best first option for your stated preference is Codex OAuth, since it
avoids a separately billed OpenAI API key. If that account lacks Codex access or
you prefer metered OpenCode Console use, switch to `opencode-zen` instead.

Hermes stores sessions, configuration, and runtime credentials on its 5 GiB
ReadWriteOnce PVC using the cluster's default StorageClass. Back up this volume
as sensitive data. The chart is pinned to upstream chart `1.28.0` and image
`v0.23.4`.
