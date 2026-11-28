# Agent Sandbox on Kubernetes 1.32: upstream compatibility and install facts

**Checked:** 2026-11-27. **Scope:** upstream primary sources only; no cluster inspection or changes.

## Bottom line

Upstream documents Kubernetes **1.25+** as the minimum and recommends **1.29+** for stable, non-disableable CRD CEL validation. Kubernetes 1.32.0 exceeds both. This is not a promise of regular CI coverage: upstream says each release is tested against the newest Kubernetes release and intermediate versions are expected to work but are not regularly tested. Thus 1.32 is within the stated minimum, but is not specifically claimed as tested. No upstream-stated hard incompatibility with core Agent Sandbox on 1.32 was found.

The minimum is tied to CRD CEL rules. Kubernetes 1.25–1.28 require `CustomResourceValidationExpressions` enabled when installing CRDs; otherwise the API server drops CEL rules and Sandbox name validation / volume-claim-template immutability are not enforced. This caveat does not apply to 1.32. Sources: [official install prerequisites](https://agent-sandbox.sigs.k8s.io/docs/getting_started/install_prerequisites/), [official overview](https://agent-sandbox.sigs.k8s.io/docs/getting_started/overview/).

Gateway API is separate: upstream says the full Gateway API v1.5.0 CRD bundle requires Kubernetes 1.31+ because of TLSRoute CEL validation. This is a Gateway API dependency, not Agent Sandbox’s baseline. Kubernetes 1.32 clears this floor if the optional gateway-based connection path is used.

## Current release and official install paths

As checked 2026-11-27, the latest GitHub release is **v1.0.12**, published Nov 20 2026. Upstream publishes:

- Core only: [sandbox.yaml](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/sandbox.yaml)
- Extensions only: [extensions.yaml](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/extensions.yaml)
- Combined core + extensions: [sandbox-with-extensions.yaml](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/sandbox-with-extensions.yaml)

Official docs call the combined manifest the standard/recommended install and recommend pinning a version for production/GitOps. They also offer `releases/latest/download/...` as a quick install. Sources: [overview install section](https://agent-sandbox.sigs.k8s.io/docs/getting_started/overview/), [installation guide](https://agent-sandbox.sigs.k8s.io/docs/getting_started/install_prerequisites/), [v1.0.12 release notes](https://github.com/kubernetes-sigs/agent-sandbox/releases/tag/v1.0.12).

The release tag resolves to commit `4863a629bd6ea0c53a70c1712c46058f4b46f81b`. Its core manifest uses image `registry.k8s.io/agent-sandbox/agent-sandbox-controller:v1.0.12`, creates namespace `agent-sandbox-system`, and configures a one-replica Deployment with a dedicated service account; metrics and health ports are 8080 and 8081. Evidence: [pinned release manifest](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/sandbox.yaml).

## APIs / CRDs

Core API: `agents.x-k8s.io/v1beta1`, kind `Sandbox`, namespaced. Extension API group: `extensions.agents.x-k8s.io`; v1beta1 kinds are `SandboxTemplate`, `SandboxClaim`, and `SandboxWarmPool`. Extensions are opt-in. Sources: [pinned core CRD](https://github.com/kubernetes-sigs/agent-sandbox/blob/4863a629bd6ea0c53a70c1712c46058f4b46f81b/config/crd/bases/agents.x-k8s.io_sandboxes.yaml), [overview](https://agent-sandbox.sigs.k8s.io/docs/getting_started/overview/), [extensions release manifest](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/extensions.yaml).

Whether OpenShell needs the extensions APIs is not established by the sources reviewed; that requires a separate OpenShell-specific check. Core-only is the smaller install if it only consumes `Sandbox`.

## RBAC and controller footprint

Core install creates service account `agent-sandbox-controller`, a `ClusterRoleBinding` to `ClusterRole/agent-sandbox-controller`, a metrics Service, and a single-replica Deployment in `agent-sandbox-system`. This is cluster-scoped RBAC rather than namespace-only authority. Inspect the exact versioned `ClusterRole` before approval. Evidence: [pinned release manifest](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/sandbox.yaml).

**RBAC evidence limit:** the authoritative release asset is available, but the fetched representation did not expose the full ClusterRole permission list in a reliably reviewable form during this investigation. I have not guessed or enumerated verbs/resources. The extensions artifact contains additional controller permissions: [extensions.yaml](https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v1.0.12/extensions.yaml).

## K3s-specific applicability

Official prerequisites state Kubernetes version/CEL requirements and the install guide applies ordinary Kubernetes manifests with `kubectl`. They do not name K3s as unsupported or require a K3s-only API. This is absence of a documented K3s blocker, **not** evidence upstream tested K3s 1.32. Compatibility still depends on the actual K3s API server version and CRD/CEL support.

Agent Sandbox is an orchestrator; upstream says it delegates isolation to configured runtimes such as gVisor or Kata via `RuntimeClass`. Storage depends on requested PVCs and the cluster's StorageClass/provisioner. These are runtime/cluster prerequisites, not an identified Kubernetes 1.32 incompatibility. [Official overview](https://agent-sandbox.sigs.k8s.io/docs/getting_started/overview/).

For gateway-based client connections, separately verify the installed Gateway API CRDs/controller and their stated 1.31+ requirement. The optional router install example uses `--authz-mode=allow-all`; upstream says this is only for local testing. [Official installation guide](https://agent-sandbox.sigs.k8s.io/docs/getting_started/install_prerequisites/).

## Implications for the next homelab review

1. Upstream’s declared version floor is satisfied by Kubernetes 1.32.0; do not describe 1.32 as specifically tested.
2. Pin a release and choose core-only vs combined based on OpenShell’s actual API requirements. v1.0.12 was latest on the check date.
3. Review exact core and (if used) extension ClusterRole rules.
4. Verify live K3s server version, CRD establishment/CEL behavior, storage class, and any requested runtime classes before deployment. No changes were applied.

## Sources and limits

Claims trace to official Kubernetes SIG Agent Sandbox documentation and release artifacts; no secondary write-ups used. The release can change: check the [official releases page](https://github.com/kubernetes-sigs/agent-sandbox/releases) before deployment. Context7 lookup was unavailable. This note does not inspect the homelab cluster or validate OpenShell’s exact CRD dependency.
