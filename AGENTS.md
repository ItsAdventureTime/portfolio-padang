# AGENTS.md — Padang ERP Lite

## Two-Agent Workflow

This project uses a two-agent software engineering workflow governed by `docs/PROJECT_CONSTITUTION.md`.

| Agent | Role | Responsibilities |
|---|---|---|
| **Google Antigravity** | Product Architect & Reviewer | Requirements, architecture, UI/UX design, security, acceptance criteria, reviews |
| **ChatGPT Codex** | Implementation Engineer | All code, migrations, containers, deployment, scripts |

**THE GIT REPOSITORY IS THE SOURCE OF TRUTH.**

---

## Before You Do Anything

Read in this order:

1. `docs/PROJECT_CONSTITUTION.md` — shared engineering rules (all agents)
2. `docs/HANDOFF.md` — current status, branch, what to do next
3. This file for the map to detailed documentation

---

## Project Identity

| Field | Value |
|---|---|
| **Client** | Bridge-PH |
| **End-client** | Padang Construction and Supplies Corporation |
| **Location** | Pampanga, Philippines |
| **Product** | Padang ERP Lite — operations management system |
| **Accounting SOT** | QuickBooks Online (ERP is operational only; no GL) |
| **Currency** | PHP (Philippine Peso) |

---

## Repository Structure

```
padang-bridge-dashboard/
├── AGENTS.md                    ← You are here
├── README.md                    ← Setup and overview
├── docs/
│   ├── PROJECT_CONSTITUTION.md  ← Engineering rules (read first)
│   ├── PRODUCT.md               ← Product requirements, modules, roles, business rules
│   ├── ARCHITECTURE.md          ← System architecture, tech stack, API design
│   ├── UI_UX.md                 ← UX patterns, flows, responsive design, accessibility
│   ├── DESIGN_SYSTEM.md         ← Color tokens, typography, component guidelines
│   ├── API.md                   ← REST API conventions, auth, endpoints reference
│   ├── DATABASE.md              ← Schema design, ERD notes, migration strategy
│   ├── SECURITY.md              ← Auth, RBAC, OWASP controls, secrets management
│   ├── TESTING.md               ← Test strategy, commands, coverage requirements
│   ├── DEPLOYMENT.md            ← Quadlet naming, Caddy config, VPS layout
│   ├── OPERATIONS.md            ← Day-to-day ops: health checks, updates, monitoring
│   ├── BACKUP_RESTORE.md        ← Backup schedule, B2 config, restore procedure
│   ├── DEPENDENCIES.md          ← Major deps, versions, support windows, OCI digests
│   ├── RESEARCH.md              ← Technical research findings and sources
│   ├── HANDOFF.md               ← Current handoff state (always up to date)
│   └── adr/                     ← Architecture Decision Records
├── backend/                     ← Go API (Chi + sqlc + PostgreSQL 17)
├── frontend/                    ← Next.js 15 (App Router + shadcn/ui)
├── quadlets/                    ← Podman Quadlet templates (demo + prod)
├── scripts/                     ← Operational bash scripts
└── seed/                        ← Demo seed data
```

---

## Key Decisions (summary — see docs for detail)

| Decision | Choice |
|---|---|
| Backend | Go (latest stable) + Chi router |
| API | REST/JSON + OpenAPI 3.1 |
| Frontend | Next.js App Router (LTS) + TypeScript |
| UI library | shadcn/ui + Tailwind CSS |
| Database | PostgreSQL 17 |
| File storage | Backblaze B2 (`bridge-ph` bucket) |
| Email | Resend (adapter pattern; future Azure) |
| Auth | Passwordless Email OTP + RS256 JWT |
| Containers | Rootless Podman Quadlets |
| Ingress | Existing Caddy (path-based routing) |
| OCI Registry | GHCR (`ghcr.io/itsadventuretime/padang-erp`) |

---

## Phase Status

See `docs/HANDOFF.md` for current phase and next action.
