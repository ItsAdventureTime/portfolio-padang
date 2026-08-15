# Padang ERP Lite

**Padang Construction and Supplies Corporation**  
Design | Construct | Supply · AAA Accredited Contractor · Pampanga, Philippines

---

## What This Is

Padang ERP Lite is an **operations management system** for Padang Construction and Supplies Corporation — a PCAB AAA-accredited ("Large B") construction and fabrication company.

QuickBooks Online (QBO) remains the official accounting system of record. This ERP captures complete operational and financial transaction details for bookkeeping entry in QBO, with export capability and a path to future live API sync.

**This system is NOT an accounting system. There is no general ledger.**

---

## For Developers — Start Here

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
jk-sbx-project exec bash -lc 'bash -n scripts/*.sh'
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

## Update the Deployed Demo

From the repository root on macOS, run:

```sh
scripts/update-padang-demo.sh
```

The command uses `jk@216.75.75.136:22` by default, preserves demo data, and
checks both `https://delegateops.business/padang/demo` and
`https://delegateops.business/padang/demo/api/v1/health` after an apply. Use
`--dry-run` to validate without changing Quadlets, secrets, Caddy, or runtime
data. Before the SSH sync, it builds the Linux/amd64 API and the
`/padang/demo` standalone frontend inside the Docker Sandbox and uploads the
prepared artifacts; the VPS does not compile or install Node/Go dependencies.
Use `--seed-demo` only when an intentional synthetic-data reset is required.
After a successful demo apply, run
`scripts/check-padang-public-routes.sh --demo-only`; use the default checker
once production is deployed as well. See `docs/DEPLOYMENT.md` for the full
runbook.

Use `scripts/check-padang-public-routes.sh --demo-only` when validating the
demo release by itself. The default check covers both environments and should
be used after production is deployed. The last end-to-end audit found HTTP 404
responses from both BunnyCDN and the direct VPS Caddy origin. Do not treat a
GitHub push or a successful local build as a public deployment.

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
| Demo | `https://delegateops.business/padang/demo` | Stakeholder preview; auto-resets every 30 min; no authentication |
| Production | `https://delegateops.business/padang` | Live system; Email OTP auth; full backups |

The demo has no authentication and contains synthetic data only. Production
uses passwordless Email OTP, RS256 access tokens, and rotating refresh tokens.
Future iOS and Android clients use the same API and business rules with
platform-appropriate secure refresh-token storage.

---

## License

Proprietary. All rights reserved. Padang Construction and Supplies Corporation / Bridge-PH.
