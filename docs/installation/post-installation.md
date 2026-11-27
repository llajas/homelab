# Post-installation

## Backup secrets

Save the following files to a safe location like a password manager (if you're using the sandbox, you can skip this step):

- `~/.ssh/id_ed25519`
- `~/.ssh/id_ed25519.pub`
- `./metal/kubeconfig.yaml`
- `~/.terraform.d/credentials.tfrc.json`
- `./external/terraform.tfvars`

## Admin credentials

- ArgoCD:
    - Username: `admin`
    - Password: run `./scripts/argocd-admin-password`
- Grafana:
    - Username: `admin`
    - Password: `prom-operator` (TODO: use random password)
- Gitea:
    - Username: `gitea_admin`
    - Password: get from `global-secrets` namespace

## SSO operations

- Kanidm is the identity source for users and groups.
- Applications authenticate directly with their Kanidm OIDC clients. The legacy Dex release no longer handles authentication; its chart is removed from desired state and Argo CD will prune the existing release on reconciliation.
- The private [`homelab-identity`](https://git.lajas.tech/ops/homelab-identity) repository owns user, group, and OAuth client desired state. Changes are reviewed and applied through its Terraform workflow.
- Users request access through the [registration portal](https://register.lajas.tech). Administrators review the resulting pull request, merge approved changes, then retrieve and privately share the temporary enrollment link through the [identity admin portal](https://portal-admin.lajas.tech).
- See [user onboarding](../getting-started/user-onboarding.md) for the complete request, approval, provisioning, and credential handoff flow.

### Upgrade notes

- Kanidm upgrades must be done sequentially between minor versions.
- This repo is pinned to the latest supported `1.10.x` hop.
- Before every Kanidm minor upgrade, run:

    ```sh
    kubectl exec -n kanidm statefulset/kanidm -- kanidmd domain upgrade-check
    ```

- Do not jump directly from `1.7.x` to `1.10.x` in a live environment.

### Kanidm staged upgrade checklist

When upgrading Kanidm, validate its direct OIDC clients and relying applications after each supported version hop:

1. Back up Kanidm data before the image change.
2. Run the pre-upgrade check:

    ```sh
    kubectl exec -n kanidm statefulset/kanidm -- kanidmd domain upgrade-check
    ```

3. Upgrade only one supported Kanidm minor hop at a time.
4. After rollout, validate Kanidm's OIDC surface:

    - issuer/discovery documents for the configured clients
    - JWKS and token endpoints
    - client authentication, scopes, and redirect URIs

5. Validate the claims applications receive directly from Kanidm:

    - `sub`
    - `email`
    - username / profile claims used at login
    - `groups` claims used for application authorization

6. Confirm login still works for:

    - Grafana, Gitea, Open WebUI, Planka, and Neko

7. Only after those checks pass should the next Kanidm minor hop be planned.

Current staged path in this repo:

- `1.7.4 -> 1.8.3`
- `1.8.3 -> 1.9.4`
- `1.9.4 -> 1.10.3`

## Run the full test suit

After the homelab has been stabilized, you can run the full test suite to ensure that everything is working properly:

```sh
make test
```

!!! info

    The "full" test suit is still in its early stages, so any contribution is greatly appreciated.
