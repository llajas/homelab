# Agent Guidelines for Homelab Repository

## Build/Test Commands
- **Full deployment**: `make` (runs metal → bootstrap → external → smoke-test → post-install)
- **Single test**: `cd test && gotestsum --format testname -- -timeout 30m -run "TestName"`
- **Filtered tests**: `cd test && make filter=Smoke` or `cd test && make filter=Integration`
- **Development setup**: `make dev` (dev cluster) | `nix-shell` (dev tools)
- **Linting**: Pre-commit hooks run yamllint, helmlint, shellcheck, terraform-fmt automatically

## Code Style & Conventions
- **Go**: Standard imports (std, external, internal), use `t.Parallel()` in tests, `terratest` for K8s testing
- **YAML**: Follow `.yamllint.yaml` (no document-start, no line-length limit), use `---` separators
- **Helm**: Use bjw-s `app-template` dependency pattern, version `0.0.0` for internal charts
- **Kubernetes**: Namespace = app name, ingress class `nginx`, TLS `letsencrypt-prod`
- **1Password secrets**: Add a `OnePasswordItem` pointing to `vaults/<vault-id>/items/<item-uuid>` and have workloads reference its generated Secret by name; Secret field names become environment-variable keys. Follow existing `apps/atuin` or `apps/opencode` examples.
- **Naming**: kebab-case for files/dirs, camelCase for Go, snake_case for scripts

## File Structure Patterns
- **Apps**: `apps/{name}/Chart.yaml` + `values.yaml` (prefer bjw-s app-template dependency)
- **Platform**: `platform/{name}/` for core infrastructure (auth, CI/CD, monitoring)
- **System**: `system/{name}/` for cluster services (networking, storage, operators)
- **Tests**: Go files in `test/` with descriptive function names, parallel execution

## Development Workflow
1. `./scripts/configure` for initial setup, `./scripts/new-service "name"` for scaffolding
2. Test locally: `make smoke-test`, fix issues before committing
3. Git hooks enforce style: `make git-hooks` to install pre-commit validation
4. All changes validated: yamllint, helmlint, shellcheck, terraform-fmt, no secrets

## Key Technologies & Error Handling
**Stack**: K3s + ArgoCD + Helm + Terraform + Ansible | **Storage**: Longhorn | **Networking**: Cilium + NGINX + cert-manager
**Testing**: Terratest with 30s retries, ignore TLS certs, expect HTTP 200 responses | **Secrets**: 1Password operator integration
