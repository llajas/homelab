# Start Game portal

This chart deploys the stateless identity request portal behind the public
Gateway API route `https://start-game.lajas.tech`. Argo CD discovers the chart
from `apps/start-game/` and creates the matching `start-game` namespace.

The Deployment runs three replicas behind a `ClusterIP` Service. Requests do not
use sticky sessions or local files. The portal's 10-attempt/minute limiter is
per replica, so three replicas allow up to 30 attempts/minute in aggregate; it
is best-effort abuse throttling, not a global quota. The Gitea API serializes
same-username branch/file creation across replicas.

The `OnePasswordItem` references the portal token item in the shared homelab
vault. The operator normalizes the field label `Gitea API token` to the Secret
key `gitea-api-token`, which the Deployment maps to `GITEA_API_TOKEN`. The token
value is not stored in this repository or included in the image.

The image is published to `registry.lajas.tech/start-game-identity-portal` by
the portal repository's Woodpecker workflow. The chart uses the `latest` tag for
initial bootstrap; update the image tag in `values.yaml` when pinning a specific
published SHA for a release.

Before enabling public onboarding, merge identity PR #4 so the upstream catalog
contains the `request-only` preset and `none` roles, then verify the bot's
effective upstream/fork permissions without exposing its token.

Validate locally with:

```sh
helm dependency update apps/start-game
helm lint apps/start-game
helm template start-game apps/start-game --namespace start-game
```
