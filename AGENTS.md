# AGENTS.md

## Agent scope

- OpenCode is used like Google for research and as a UI engineer due to limited CSS/design skills — never for backend code, infrastructure/deployment manifests, scripts, or similar artifacts.

## Toolchain

- `mise` manages Go 1.25.8, golangci-lint 2.6.1, k8s-gen, cloud-provider-kind, and hostctl (see `mise.toml`).
- `make` is the canonical task runner. There is no `justfile` in this worktree; old `just` references are stale.
- `direnv` loads `.envrc`: sets `SOPS_AGE_KEY` from a 1Password item and `KUBECONFIG` to all `*.kubeconfig.yaml` files under the repo.
- Linter ignores `deploy/.*` and `templates/*` (`.golangci.json`).

## Everyday commands

| Task | Command |
|---|---|
| Run tests | `make test` |
| Lint | `make lint` |
| Build snapshot release + load amd64 image into kind | `make build` |
| Full release | `make release` |
| Generate templ files | `make gen-templates` |
| Generate DB query layer | `make gen-query` |
| Create kind cluster | `make cluster-create` |
| Apply Tanka CRDs | `make tk-apply-crds` |
| Apply remaining Tanka manifests | `make tk-apply` |
| Tanka diff | `make tk-diff` |
| Tanka lint | `make tk-lint` |
| Restart server deployment | `make server-restart` |
| Start cloud-provider-kind + gateway sync | `make kind-lb` |
| Sync gateway IPs to `/etc/hosts` | `make sync-gw-to-hosts` |

## Code generation

- `templates/**/*.templ` → `make gen-templates` → `templates/**/*_templ.go`.
- `internal/storage/model/*.go` → `make gen-query` → `internal/storage/query/*.gen.go`.

## Do not edit

- `templates/**/*_templ.go`
- `internal/storage/query/*.gen.go`
- The `go:generate` directive in `internal/client/lib/apiclient/generate.go` is stale: it references a removed `api/` directory.

## Architecture

- Two binaries: `cmd/telesto-server` (serves) and `cmd/telestoctl` (CLI).
- Server is a plain `chi` router with server-rendered `templ` pages and Kratos-based session middleware.
- Storage: GORM over Postgres (not rqlite). Migration is opt-in via `storage.migrate: true` in config.
- Config: `telesto serve --config telesto.json` (JSON). Env prefix is `TL_`, and both `.` and `-` are mapped to `*` in env keys (e.g., `server.address` → `TL_SERVER*ADDRESS`).
- Container entrypoint: `/usr/bin/telesto serve`.
- Deploy: Tanka Jsonnet in `deploy/environments/local/`; Helm charts vendored in `deploy/charts/`; image is `ghcr.io/thisisibrahimd/telesto`.

## Local Kubernetes

- Kind cluster name: `cluster-local-telesto`; config: `deploy/cluster-local-telesto/cluster-local-telesto.yaml`.
- `make build` runs a snapshot GoReleaser build and loads the amd64 image into kind.
- `make kind-lb` runs `cloud-provider-kind` and a gateway IP sync loop.
- Gateway hostnames use `*.t.telesto.test`; sync them to `/etc/hosts` with `make sync-gw-to-hosts` (requires passwordless `hostctl`, set up via `make sudoers-install`).

## Testing

- Only `internal/server/server_test.go` exists; it is currently fully commented out.
- `make test` runs `go test ./...`; no active integration tests.

## Secrets

- `secrets/local/tanka.json` is encrypted with sops (age). `make tk-*` decrypts it via `SOPS_AGE_KEY` from `.envrc`.
- `.envrc` pulls the age key from 1Password; 1Password CLI must be authenticated.

## CLI env vars

- `telestoctl login` reads `TELESTO_USERNAME` and `TELESTO_PASSWORD`.
- Other commands use `TELESTO_TOKEN` for bearer auth.
