# OpenShell

Argo CD discovers this application through the `ai/*` ApplicationSet. The
upstream Helm chart is pinned to `v0.1.10`; the gateway remains `ClusterIP` and
does not have an ingress or public route. Kubernetes sandbox user namespaces
are enabled on K3s `v1.36.6+k3s1`.

The chart requires the Agent Sandbox controller/CRD and enforced Kubernetes
NetworkPolicies. The pinned Agent Sandbox controller is already deployed in
`agent-sandbox-system`, and live Cilium configuration has
`enable-k8s-networkpolicy: "true"`. The chart's `agentSandbox.preflight` checks
for the API during installation.

## Identity provider prerequisite

The private `homelab-identity` repository owns the Kanidm public PKCE client
`openshell-cli`, its `openshell_admins` and `openshell_users` groups, and the
`openid`/`groups` scopes. Its successful `main` apply publishes the public
client ID to the 1Password Login item
`homelab-kanidm-openshell-oidc-client-id`. This chart references that item's
UUID through `OnePasswordItem`; the generated Secret's `client_id` field is the
gateway's expected OIDC audience. The gateway waits for the Secret to be
created before starting.

Kanidm localhost redirects are the remaining manual login prerequisite. The
pinned Terraform provider does not expose this setting, so an authorized
Kanidm operator must enable it before the first CLI login:

```bash
kanidm system oauth2 enable-localhost-redirects openshell-cli
```

The gateway validates the `groups` claim. Add the intended users to Kanidm
groups `openshell_users` and/or `openshell_admins`; Kanidm emits their SPNs in
the claim. Platform admins bypass workspace membership checks, so restrict
`openshell_admins` to trusted operators. Configure these groups and the client
in the identity repository; they are not created by this chart.

The gateway stores provider credentials as Kubernetes Secrets in the dedicated
`openshell-credentials` namespace. Its generated Role is confined to that
namespace. The chart also creates a ClusterRole for `tokenreviews.create` and
read-only node access, required by the Kubernetes driver.

## Connect the CLI

After GitOps sync and the StatefulSet is ready, keep this port-forward running:

```bash
kubectl -n openshell port-forward svc/openshell 8080:8080
```

In another terminal, install the generated CA for TLS verification and register
the gateway. Kanidm authentication uses Authorization Code + PKCE; add the
`groups` scope so the access token carries OpenShell roles.

```bash
mkdir -p ~/.config/openshell/gateways/homelab/mtls
kubectl -n openshell get secret openshell-client-tls \
  -o jsonpath='{.data.ca\.crt}' | base64 -d \
  > ~/.config/openshell/gateways/homelab/mtls/ca.crt
OPENSHELL_CALLBACK_PORT=18080 openshell gateway add https://127.0.0.1:8080 \
  --name homelab \
  --oidc-issuer https://auth.lajas.tech/oauth2/openid/openshell-cli \
  --oidc-client-id openshell-cli \
  --oidc-audience openshell-cli \
  --oidc-scopes groups
```

Use the same `OPENSHELL_CALLBACK_PORT` value for later `openshell gateway
login homelab` calls. Do not expose the gateway publicly without separately
designing and configuring an authenticated access path.
