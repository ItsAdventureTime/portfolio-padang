# Padang ERP Lite

## Demo deployment

The planned demo URL is `https://padang.delegateops.business/`. Its public route
still needs deployment and verification. The [OrbStack deployment
guide](docs/MACOS-DOCKER-COMPOSE.md) has the ordered commands and current
release hold.

**Padang Construction and Supplies Corporation**  
Design | Construct | Supply · AAA Accredited Contractor · Pampanga, Philippines

---

## About

Padang ERP Lite is an operations app for Padang Construction and Supplies
Corporation, a construction and fabrication company in Pampanga. The current
demo shows a dashboard and read-only registers. Editing, approvals, payments,
uploads, and QBO exports are still being built.

QuickBooks Online (QBO) remains the accounting system of record. Padang ERP
Lite has no general ledger.

---

## For developers

1. Read `AGENTS.md` for the project map.
2. Read `docs/PROJECT_CONSTITUTION.md` for engineering rules.
3. Read `docs/HANDOFF.md` for current phase and next action.
4. Read `docs/PLANNING_CLARIFICATIONS.md` for resolved intake decisions.
5. Read the relevant `docs/` file for your work area.
6. Read `docs/GIT_WORKFLOW.md` before committing or updating GitHub.

## Local Development

> **macOS execution policy:** Do not run application services, package
> managers, builds, or tests directly on macOS. Use the deterministic Docker
> Sandbox for project workloads. Local Podman is not the development runtime.
> See `docs/TESTING.md` and `docs/GIT_WORKFLOW.md`.

### Prerequisites

- Docker Desktop / Docker Sandbox support
- `jk-sbx-project`
- Git
- authenticated GitHub CLI (`gh`) for repository synchronization

### Quick Start (Docker Sandbox)

```sh
# Initialize or resume the project sandbox
jk-sbx-project ensure

# Run a project command inside the sandbox
jk-sbx-project validate 'bash -n scripts/*.sh'
```

Use the commands in `docs/TESTING.md` for backend, frontend, and deployment
validation. The existing `scripts/start-padang-local.sh` is a Podman-based
helper and is not the macOS default under the Docker Sandbox policy; do not
invoke it directly on the host. The application remains a foundation preview:
current module screens are read-only registers, not the completed ERP CRUD and
approval workflows.

If a sandbox workload runs out of memory, inspect the sandbox status and adjust
the Docker Sandbox resources before retrying; do not stop unrelated host
containers.

## Release or update the demo

Use the [OrbStack deployment guide](docs/MACOS-DOCKER-COMPOSE.md) for both the
first release and upgrades. It covers the PostgreSQL volume check, file-backed
secret, image export, migration, seed, Cloudflare Tunnel route, and public
health checks. The older `scripts/update-padang-demo.sh` deploys to a VPS and
is not the active demo release path. Stop at the release hold in
[HANDOFF.md](docs/HANDOFF.md) until the password handling fix passes review.

---

## Documentation Index

| Document | Purpose |
|---|---|
| `AGENTS.md` | Agent roles and project map |
| `docs/PROJECT_CONSTITUTION.md` | Engineering rules for both agents |
| `docs/PRODUCT.md` | Requirements, modules, roles, business rules |
| `docs/ARCHITECTURE.md` | System architecture and tech stack |
| `docs/UI_UX.md` | UX flows, responsive design, accessibility |
| `docs/DESIGN_SYSTEM.md` | Design tokens, typography, component patterns |
| `docs/API.md` | REST API conventions and endpoint reference |
| `docs/DATABASE.md` | Schema design and migration strategy |
| `docs/SECURITY.md` | Auth, RBAC, OWASP controls |
| `docs/TESTING.md` | Test strategy and commands |
| `docs/MACOS-DOCKER-COMPOSE.md` | Manual OrbStack demo release and rollback |
| `docs/GIT_WORKFLOW.md` | Branch, Conventional Commit, and HTTPS-only GitHub workflow |
| `docs/DEPLOYMENT.md` | Quadlet naming, Caddy, VPS layout |
| `docs/OPERATIONS.md` | Health checks, updates, monitoring |
| `docs/BACKUP_RESTORE.md` | Backup schedule and restore procedure |
| `docs/DEPENDENCIES.md` | Dependencies, versions, OCI digests |
| `docs/RESEARCH.md` | Technical research findings |
| `docs/PLANNING_CLARIFICATIONS.md` | Resolved planning decisions and implementation analogies |
| `docs/HANDOFF.md` | Current handoff state |
| `docs/adr/` | Architecture Decision Records |

---

## Environments

| Environment | URL | Purpose |
|---|---|---|
| Demo | `https://padang.delegateops.business/` | Stakeholder preview; manual synthetic-data reset; no authentication |
| Production | `https://delegateops.business/prod/padang` | Planned authenticated operations and backups |

The demo has no authentication and contains synthetic data only. The production
design uses passwordless Email OTP, RS256 access tokens, and rotating refresh tokens.
Future iOS and Android clients use the same API and business rules with
platform-appropriate secure refresh-token storage.

---

## License

Proprietary. All rights reserved. Padang Construction and Supplies Corporation / Bridge-PH.
