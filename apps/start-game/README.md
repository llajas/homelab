# Start Game portal

This chart deploys the stateless identity request portal behind the public
Gateway API route `https://start-game.lajas.tech`. Argo CD discovers the chart
from `apps/start-game/` and creates the matching `start-game` namespace.

The Deployment runs three replicas behind a `ClusterIP` Service. Requests do not
use sticky sessions or local files. The portal's 10-attempt/minute limiter is
per replica, so three replicas allow up to 30 attempts/minute in aggregate; it
is best-effort abuse throttling, not a global quota. The Gitea API serializes
same-username branch/file creation across replicas.

The `OnePasswordItem` references the public portal token item in the shared
homelab vault. The operator exposes the field label `Gitea API Token` as the
Secret key `Gitea-API-Token`, which the public Deployment maps to
`GITEA_API_TOKEN`. The public pod receives only that field and has no Kubernetes
API token.

The image is published to `registry.lajas.tech/start-game-identity-portal` by
the portal repository's Woodpecker workflow. The chart uses the `latest` tag for
initial bootstrap; update the image tag in `values.yaml` when pinning a specific
published SHA for a release.

Before enabling public onboarding, merge identity PR #4 so the upstream catalog
contains the `request-only` preset and `none` roles, then verify the bot's
effective upstream/fork permissions without exposing its token.

## Admin enrollment links

The separate `portal-admin` controller runs one replica with a persistent PVC and
uses `portal-admin.lajas.tech`, a separate `ClusterIP` Service, an HTTPRoute to the
public Cilium Gateway, and a NetworkPolicy permitting only the Gateway and
Woodpecker namespaces. It receives no HCP Terraform token. The trusted main-branch
identity pipeline sends the active onboarding-token map over HTTPS; the admin
service encrypts the map on its PVC and ignores stale state serials.

Before syncing this chart:

1. Create three 1Password items and replace the three
   `REPLACE_WITH_PORTAL_ADMIN_*_ITEM_ID` values under `opSecrets.secrets` with
   their item IDs. Add these fields with the exact names shown:

   | 1Password item | Required fields |
   | --- | --- |
   | `portal-admin-secrets` | `OIDC-Client-Secret`, `OIDC-Admin-Subject`, `Cookie-Key`, `Handoff-Token`, `Token-Store-Key` |
   | `portal-admin-recovery-password` | `Recovery-Password-Bcrypt` |
   | `portal-admin-recovery-totp` | `Recovery-TOTP-Secret` |

2. Copy the sensitive `identity_portal_admin_client_secret` Terraform output to
   `OIDC-Client-Secret`; set `OIDC-Admin-Subject` to the immutable Kanidm `sub`
   for `llajas` and ensure that account requires MFA.
3. Generate independent random values for the cookie key, encrypted-store key,
   and handoff key. The handoff key must be the same base64url-encoded 32-byte
   value in `Handoff-Token` and Woodpecker's `admin_handoff_token` secret, whose
   event filter must be limited to `push`.
4. Generate a unique recovery password hash and TOTP seed, store each only in its
   corresponding recovery item, then roll the admin controller after secret
   rotation.
5. After the portal image build publishes its commit-SHA tag, replace
   `sha-SET_AFTER_TRUSTED_BUILD` on the admin controller with that immutable tag
   (or a registry digest). Do not run the secret-bearing admin pod on `latest`.
6. Sync the chart and confirm the `portal-admin` HTTPRoute is accepted before
   merging the identity workflow change that enables handoff.

The `portal-admin-recovery-totp` item ID remains a placeholder until you create
that separate item and replace it in `values.yaml`. Do not sync the chart while
that ID or the admin image tag is still a placeholder. The TOTP item ID must be
different from the recovery password item ID; identical IDs refer to the same
1Password item.

For `Recovery-TOTP-Secret`, add a normal password or text field containing the
stable, unpadded Base32 seed. Do not use the OTP field's rotating six-digit code:
the pod needs the seed to validate user-entered codes. If you used a 1Password
OTP field, copy its setup/secret key into this normal field; never copy the
currently displayed code.

Validate locally with:

```sh
helm dependency update apps/start-game
helm lint apps/start-game
helm template start-game apps/start-game --namespace start-game
```
