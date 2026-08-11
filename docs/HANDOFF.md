# HANDOFF.md — Padang ERP Lite

---

CURRENT AGENT: Google Antigravity (Architect)
CURRENT PHASE: Phase 0 — Repository Bootstrap
STATUS: Complete. Ready for Phase 1 handoff to ChatGPT Codex.
BRANCH: docs/phase-0
BASE COMMIT: (initial commit — see LATEST COMMIT below)
LATEST COMMIT: (see below — set after commit)
REMOTE PUSH STATUS: Pending (no remote configured yet — see UNRESOLVED QUESTIONS)

---

COMPLETED:
- Git repository initialized on `main` branch; renamed from `master`
- `.gitignore` created
- `AGENTS.md` created — concise project map for both agents
- `README.md` created — project overview and developer entry point
- `docs/PROJECT_CONSTITUTION.md` created — project-specific engineering rules
- `docs/PRODUCT.md` created — full product requirements, roles, modules, business rules, PH regulatory context
- `docs/ARCHITECTURE.md` created — system architecture, tech stack, component layout
- `docs/UI_UX.md` created — UX principles, key flows, page layouts, responsive behavior
- `docs/DESIGN_SYSTEM.md` created — complete design tokens, typography, component patterns, animations
- `docs/API.md` created — REST API conventions, auth, response envelopes, all endpoint reference
- `docs/DATABASE.md` created — schema design, table DDL, index strategy, migration approach
- `docs/SECURITY.md` created — auth, RBAC, secrets, OWASP controls, container security
- `docs/TESTING.md` created — test strategy, coverage requirements, E2E flows, all test commands
- `docs/DEPLOYMENT.md` created — Quadlet files, naming convention, VPS layout, Caddy config
- `docs/OPERATIONS.md` created — health checks, log access, service management, troubleshooting
- `docs/BACKUP_RESTORE.md` created — backup schedule, B2 config, Quadlet, restore procedure, DR plan
- `docs/DEPENDENCIES.md` created — all dependencies with versions, OCI digests, support windows
- `docs/RESEARCH.md` created — all research findings, decisions, and sources from discovery phase
- `docs/adr/ADR-001` through `ADR-007` created — all architecture decisions documented
- `docs/HANDOFF.md` created (this file)

CHANGED FILES:
- .gitignore (NEW)
- AGENTS.md (NEW)
- README.md (NEW)
- docs/PROJECT_CONSTITUTION.md (NEW)
- docs/PRODUCT.md (NEW)
- docs/ARCHITECTURE.md (NEW)
- docs/UI_UX.md (NEW)
- docs/DESIGN_SYSTEM.md (NEW)
- docs/API.md (NEW)
- docs/DATABASE.md (NEW)
- docs/SECURITY.md (NEW)
- docs/TESTING.md (NEW)
- docs/DEPLOYMENT.md (NEW)
- docs/OPERATIONS.md (NEW)
- docs/BACKUP_RESTORE.md (NEW)
- docs/DEPENDENCIES.md (NEW)
- docs/RESEARCH.md (NEW)
- docs/adr/ADR-001-go-chi-backend.md (NEW)
- docs/adr/ADR-002-nextjs-frontend.md (NEW)
- docs/adr/ADR-003-postgresql-database.md (NEW)
- docs/adr/ADR-004-sqlc-database-access.md (NEW)
- docs/adr/ADR-005-backblaze-b2-storage.md (NEW)
- docs/adr/ADR-006-email-adapter-pattern.md (NEW)
- docs/adr/ADR-007-path-based-routing.md (NEW)

ARCHITECTURAL DECISIONS:
- Go (1.24+) + Chi v5 — idiomatic, minimal, long-lived ERP backend
- Next.js 15 App Router + TypeScript + shadcn/ui + Tailwind CSS v4 — hybrid SSR/CSR frontend
- PostgreSQL 17 — relational ERP data model
- sqlc + pgx v5 — type-safe SQL, no ORM
- golang-migrate — DB migrations (up/down SQL files)
- Backblaze B2 (existing bucket `bridge-ph`) — file storage + production backups
- Resend → Azure (future) — provider-neutral email adapter
- Rootless Podman Quadlets — all containers
- Path-based routing: /padang (prod), /padang/demo (demo) — existing Caddy
- RS256 JWT — access (15min) + refresh (7d, rotating, server-side hashed)
- GHCR as OCI registry — org name TBD (open question)
- VAT 12% + EWT 2% at launch — BIR-compliant billing documents
- Retention 10% per billing + release mechanism — CIAP standard
- Variation Orders (10% cumulative cap) — at launch
- RPO ≤ 24h (daily pg_dump to B2); RTO ≤ 4h — recommended defaults

DEPENDENCY CHANGES:
None — no application code written in Phase 0.

DATABASE CHANGES:
Schema designed in docs/DATABASE.md.
No migrations run — no DB containers exist yet.

INFRASTRUCTURE CHANGES:
None — no Quadlets deployed, no VPS changes made.

---

COMMANDS EXECUTED:
- `git init` (local only)
- `git branch -m master main`
- File creation only

TESTS EXECUTED: None (Phase 0 is documentation only)
TEST RESULTS: N/A
KNOWN FAILURES: None
KNOWN RISKS:
- ADR-007: Caddy existing config must be inspected before adding path routing rules
  → Codex must SSH and read Caddyfile BEFORE writing any Caddy changes
- GHCR org name is unknown — Quadlet files use placeholder `<org>` — must be resolved before image push
- Resend API key existence on VPS is unknown — must be confirmed before email testing
- DCS role name: confirmed as Disbursing/Check Signing Officer (role, not just a workflow step)

---

UNRESOLVED QUESTIONS:
1. GitHub org/username for GHCR: `ghcr.io/<org>/padang-erp-api` — replace `<org>` everywhere in docs/DEPLOYMENT.md and Quadlets
2. Does Resend API key already exist in Podman secrets on VPS? (`bridge-ph-padang-demo-resend-key`, `bridge-ph-padang-prod-resend-key`)
3. Is Caddy config a Caddyfile or JSON config? SSH to VPS and inspect before any Caddy changes.
4. Go-live timeline — not specified; implementation should proceed without blocking on this

OPEN DEFECTS: None

---

NEXT REQUIRED ACTION:
ChatGPT Codex to begin Phase 1 — Database Schema & Migrations.

Phase 1 scope:
1. Initialize Go module: `go mod init github.com/<org>/padang-erp` (replace <org>)
2. Set up directory structure per docs/ARCHITECTURE.md (backend/)
3. Set up golang-migrate with PostgreSQL dialect
4. Write migration files for ALL tables defined in docs/DATABASE.md:
   - users, refresh_tokens
   - projects, project_budget_items, project_variation_orders, project_progress_entries
   - fabrication_jobs
   - suppliers, purchase_requests, purchase_request_items, purchase_orders
   - fund_requests
   - inventory_items, inventory_transactions
   - progress_billings, progress_billing_items, collections
   - attachments (polymorphic)
   - audit_log (append-only; include index and trigger to prevent UPDATE/DELETE)
   - All sequences for reference number generation
   - All indexes documented in DATABASE.md
5. Set up sqlc.yaml and write initial query files for at least: users CRUD, projects CRUD
6. Set up Podman-based local development: throwaway PostgreSQL container for migration testing
7. Verify all migrations run up and down cleanly
8. Write the initial commit: `feat(db): initial schema migrations and sqlc setup`

NEXT AGENT: ChatGPT Codex (Implementation Engineer)

REQUIRED READING (for Codex):
1. AGENTS.md — project map and role assignments
2. docs/PROJECT_CONSTITUTION.md — engineering rules (especially macOS execution policy, secrets policy, Git rules)
3. docs/HANDOFF.md — this file
4. docs/ARCHITECTURE.md — directory structure, tech stack
5. docs/DATABASE.md — schema design and DDL
6. docs/SECURITY.md — secrets, RBAC
7. docs/DEPLOYMENT.md — naming conventions

APPROVAL REQUIRED:
Phase 1 is pre-authorized. Codex may begin immediately.
Any material deviation from the documented architecture requires flagging to Antigravity (Architect) before proceeding.
