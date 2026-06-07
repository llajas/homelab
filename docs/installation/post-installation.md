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
- Dex remains the application-facing OIDC broker for Grafana, Gitea, Open WebUI, and Planka.
- Onboard a user with:

    ```sh
    ./scripts/onboard-user johndoe "John Doe" johndoe@example.com
    ```

- Add specific groups during onboarding by passing them after the email address.
- Recover a user's initial credential with:

    ```sh
    ./scripts/kanidm-reset-password johndoe
    ```

### Upgrade notes

- Dex can be updated independently.
- Kanidm upgrades must be done sequentially between minor versions.
- This repo is pinned to the latest supported `1.8.x` hop before any future `1.9.x` or `1.10.x` upgrade.
- Before every Kanidm minor upgrade, run:

    ```sh
    kubectl exec -n kanidm statefulset/kanidm -- kanidmd domain upgrade-check
    ```

- Do not jump directly from `1.7.x` to `1.10.x` in a live environment.

### Kanidm staged upgrade checklist

When upgrading Kanidm with Dex still in front of applications, use this order of operations:

1. Back up Kanidm data before the image change.
2. Run the pre-upgrade check:

    ```sh
    kubectl exec -n kanidm statefulset/kanidm -- kanidmd domain upgrade-check
    ```

3. Upgrade only one supported Kanidm minor hop at a time.
4. After rollout, validate the Dex upstream OIDC surface:

    - issuer/discovery document at `https://auth.lajas.tech/oauth2/openid/dex`
    - JWKS and token endpoints
    - client authentication for Dex's `kanidm` connector
    - scopes and redirect URI behavior for the `dex` OAuth2 client in Kanidm

5. Then validate the claims that dependent apps still receive through Dex:

    - `sub`
    - `email`
    - username / profile claims used at login
    - `groups` claims used for Grafana and Planka authorization

6. Confirm login still works for:

    - Grafana
    - Gitea
    - Open WebUI
    - Planka

7. Only after those checks pass should the next Kanidm minor hop be planned.

## Run the full test suit

After the homelab has been stabilized, you can run the full test suite to ensure that everything is working properly:

```sh
make test
```

!!! info

    The "full" test suit is still in its early stages, so any contribution is greatly appreciated.
