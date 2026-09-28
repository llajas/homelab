# OpenCode remote server

This chart runs one authenticated OpenCode backend in Kubernetes while the TUI
continues to run on the workstation. Argo CD discovers the chart through the
repository's `apps/*` ApplicationSet.

The deployment deliberately uses one replica and the `Recreate` strategy. Do
not change it to a rolling or multi-replica deployment: the server and its
persistent application state are not treated as interchangeable.

## Required inputs

Verify these values in `values.yaml` before syncing the application:

| Value | Default | Required verification |
| --- | --- | --- |
| `workspace.nfs.server` | `nas-01.storage.lajas.tech` | Resolves from every K3s node |
| `workspace.nfs.path` | `/mnt/user/ghq` | Matches the Unraid NFS export |
| UID/GID | `1000:1000` | Matches the workstation user and NFS ownership |
| `opSecrets.vault` | `z3emsr5qi5xqk33wthv5fpmfqa` | ID of the `homelab` vault |
| `opSecrets.item` | `4msntvjd4yesnjuli2ywrkic5i` | ID of the `OpenCode Server` item |
| Image | `registry.lajas.tech/opencode:1.18.32-1` | Built and pushed before Argo sync |

The chart pins the published image digest as well as its human-readable tag.
When rebuilding the tag, update the digest only after verifying the new registry
manifest.

Confirm the workstation identity with `id -u` and `id -g`; change every
`1000` security-context value together if either result differs. Upgrade the
local OpenCode client to the same `1.18.32` release as the server before the
first attach test.

Create the 1Password item with these fields:

| Field | Value |
| --- | --- |
| `username` | `opencode_server` |
| `password` | A strong generated password |
| `htpasswd` | `opencode_server:<password hash>` |

The 1Password operator creates the `opencode-server-auth` Secret. Provider
credentials are separate. Authenticate providers after deployment from the
remote environment, and never add `auth.json` to Git.

Generate the `htpasswd` value without storing the plaintext in shell history:

```bash
docker run --rm -it httpd:2.4.65-alpine htpasswd -nB opencode_server
```

The command prompts for the password without placing it in shell history. Copy
the complete `opencode_server:<hash>` line into the item. The local client reads
the same plaintext from the item's `password` field.

## Image

There is no currently documented official general-purpose OpenCode server
image. The chart consumes the separately built and published
`registry.lajas.tech/opencode:1.18.32-1` image, which installs the pinned
official `opencode-ai@1.18.32` package and adds the baseline infrastructure
tools. Image source and publishing automation belong in a dedicated repository,
not in this homelab chart.

The image includes Bash, Git, OpenSSH, curl, wget, jq, yq, ripgrep, fd, GitHub
CLI, Python, Node/npm, kubectl, Helm, Kustomize, Make, and C/C++ build tools.
Add heavier language toolchains only when a real repository requires them.

## Storage and permissions

The static `opencode-ghq` PV uses the Unraid export with `ReadWriteMany` and a
`Retain` policy. It is mounted at `/workspace/ghq`. The application home is a
separate retained Longhorn `ReadWriteOnce` claim mounted at `/home/opencode`;
this persists configuration, provider auth, session data, databases, and cache
without putting SQLite state on NFS.

Before the first sync, create the Unraid share, export it over NFS, and set its
numeric ownership to the verified workstation UID/GID. Do not use `0777` as a
substitute for correct ownership. If Unraid uses root squashing, pre-create the
export and ownership from Unraid rather than relying on a root init container.

Mount the same export on the workstation at `$HOME/ghq`. A representative
`/etc/fstab` entry is shown below; confirm the NFS version and mount options
against the Unraid export instead of copying it blindly:

```fstab
nas-01.storage.lajas.tech:/mnt/user/ghq /home/red/ghq nfs4 rw,_netdev,noatime 0 0
```

Validate the mount with a temporary pod before starting OpenCode:

```bash
kubectl -n opencode run nfs-check --rm -it --restart=Never \
  --image=alpine:3.22 \
  --overrides='{"spec":{"containers":[{"name":"nfs-check","image":"alpine:3.22","command":["sh"],"stdin":true,"tty":true,"volumeMounts":[{"name":"ghq","mountPath":"/workspace/ghq"}]}],"volumes":[{"name":"ghq","persistentVolumeClaim":{"claimName":"opencode-ghq"}}]}}'
```

## Internal routing and authentication

`opencode.lajas.tech` attaches only to the HTTPS listener on
`kube-system/public-gateway`. Cloudflare ExternalDNS and both Pi-hole
ExternalDNS instances create records from the same HTTPRoute, each pointing to
the gateway VIP (`10.138.0.226`). It has none of the annotations used by the
Cloudflare tunnel publication workflow.

Basic Auth terminates in an nginx sidecar. OpenCode itself listens only on pod
loopback port `4097` and never receives the server password, so agent shell
commands cannot inherit or print it. Only the hashed `htpasswd` key is projected
into the proxy container, and the proxy removes the client `Authorization`
header before forwarding an authenticated request to OpenCode.

The ServiceAccount has no RBAC and does not mount a token. This is intentional.
If direct `kubectl` or Helm access is later required, add narrowly scoped RBAC
for the exact namespaces and resources; do not mount an administrator
kubeconfig or grant `cluster-admin`.

Git authentication is also intentionally not provisioned yet. Add a dedicated,
limited-purpose GitHub/Gitea token or SSH key through 1Password when repository
push access is required. Never mount the workstation's complete `.ssh`
directory; when SSH is used, provide a dedicated key and pinned `known_hosts`.

## Server-side OpenCode configuration

Repository-local OpenCode files remain on the shared workspace and load on the
server. Global provider, agent, MCP, shell, and permission configuration belongs
under `/home/opencode/.config/opencode` on the Longhorn claim. Provider auth and
session state belong under `/home/opencode/.local` on the same claim. TUI-only
preferences such as `tui.json` stay on the workstation.

The current project config only enables the `tmux` plugin. Review whether that
plugin is needed by the remote backend before copying any global configuration.
Do not copy the workstation configuration wholesale or commit credentials.

To authenticate providers, start a shell in the pod and run the supported
OpenCode connect flow there. Complete any browser step locally; the resulting
credential must be written to the remote persistent home.

```bash
kubectl -n opencode exec -it deploy/opencode -- opencode auth login
```

## Local client wrapper

Keep the local OpenCode binary installed, then add the wrapper to the shell:

```bash
alias opencode="$HOME/ghq/github.com/llajas/homelab/scripts/opencode-remote"
export OPENCODE_SERVER_USERNAME=opencode_server
export OPENCODE_SERVER_PASSWORD="$(op read 'op://z3emsr5qi5xqk33wthv5fpmfqa/4msntvjd4yesnjuli2ywrkic5i/password')"
```

The wrapper maps `$HOME/ghq` to `/workspace/ghq`, rejects directories outside
that tree, and forwards remaining arguments to `opencode attach`. Override the
defaults with `OPENCODE_LOCAL_ROOT`, `OPENCODE_REMOTE_ROOT`,
`OPENCODE_SERVER_URL`, or `OPENCODE_REAL_BIN`.

## Migration and acceptance

1. Copy the existing local `ghq` tree to the new Unraid share without deleting
   the source, mount it temporarily, validate repositories, and benchmark `git
   status`, `git diff --stat`, `git grep`, `rg`, and metadata traversal.
2. Mount the NFS share permanently at `$HOME/ghq`, then validate bidirectional
   file creation and numeric ownership between the workstation and a pod.
3. Verify the pinned image exists, create the 1Password item, sync the chart, and verify an
   unauthenticated request is rejected.
4. Authenticate providers remotely and confirm a normal model request succeeds.
5. Start sessions from at least three repositories with the wrapper. Run
   `hostname`, `uname -a`, and `pwd` to prove tools execute in Kubernetes. Do
   not dump the complete environment into model context.
6. Delete the pod, reconnect, and confirm session history and provider auth
   survive.

Useful checks:

```bash
test "$(curl --silent --output /dev/null --write-out '%{http_code}' \
  https://opencode.lajas.tech/global/health)" = 401
curl --fail --silent --show-error \
  --user "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" \
  https://opencode.lajas.tech/global/health | jq -e '.healthy == true'
kubectl -n opencode exec deploy/opencode -- pwd
kubectl -n opencode exec deploy/opencode -- opencode --version
```

The first curl must fail with `401`; the authenticated request must report a
healthy server. OpenCode's development branch is moving toward `/api/health`,
so re-check the endpoint and the loopback exec probes when changing the pinned
OpenCode version.

Back up the Unraid share and the Longhorn home claim independently. Treat any
backup containing provider auth as sensitive, and test restore procedures before
deleting the original workstation repository copy.
