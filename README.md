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

> **macOS execution policy:** Do not run application services directly on macOS.
> Use Podman containers for all runtime operations.
> See `docs/DEPLOYMENT.md` for local development container setup.

### Prerequisites

- Podman (installed and machine running)
- Git

### Quick Start (development containers)

```sh
# Start an ephemeral demo API and Next.js frontend in Podman
scripts/start-padang-local.sh
```

Open `http://127.0.0.1:3000/padang/demo` and check
`http://127.0.0.1:8080/api/v1/health`. If either port is already in use, pass
`--web-port 3100 --api-port 8180`. The helper keeps the API and frontend
runtime inside disposable Podman containers, uses no credentials or database,
and removes its pod when you press Ctrl-C. It is a foundation preview: the
current module screens are read-only registers, not the completed ERP CRUD and
approval workflows.

If the helper reports an OOM-killed frontend, increase available Podman VM
memory or pause unrelated containers before retrying; it never stops containers
that it did not create.

## Update the Deployed Demo

From the repository root on macOS, run:

```sh
scripts/update-padang-demo.sh
```

The command uses `jk@216.75.75.136:22` by default, preserves demo data, and
checks both `https://delegateops.business/padang/demo` and
`https://delegateops.business/padang/demo/api/v1/health` after an apply. Use
`--dry-run` to validate without changing Quadlets, secrets, Caddy, or runtime
data. Use `--seed-demo` only when an intentional synthetic-data reset is
required. After a successful apply, check both environments with
`scripts/check-padang-public-routes.sh`. See `docs/DEPLOYMENT.md` for the full
runbook.

The public route check is currently a release gate: the last end-to-end audit
found HTTP 404 responses from both BunnyCDN and the direct VPS Caddy origin.
Do not treat a GitHub push or a successful local build as a public deployment.

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
