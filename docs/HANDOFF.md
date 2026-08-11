# HANDOFF.md — Padang ERP Lite

---

CURRENT AGENT: Google Antigravity (Architect)
CURRENT PHASE: Phase 0 — Repository Bootstrap
STATUS: Complete. All open questions resolved. Ready for Phase 1 handoff to ChatGPT Codex.
BRANCH: docs/phase-0
BASE COMMIT: (initial commit)
LATEST COMMIT: See git log — latest is "docs(phase-0): resolve open questions from architect review"
REMOTE: https://github.com/ItsAdventureTime/bridge-padang.git
REMOTE PUSH STATUS: Pushed to origin/docs/phase-0

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
- All open questions from initial Phase 0 resolved (see below)

---

RESOLVED QUESTIONS:

1. GHCR org: `itsadventuretime` (GitHub: https://github.com/ItsAdventureTime/bridge-padang.git)
   - All OCI image references updated: `ghcr.io/itsadventuretime/padang-erp-{api|frontend}`
   - Go module path: `github.com/ItsAdventureTime/padang-erp`
   - Git remote: `gh repo` / `https` auth only; `gh` CLI is authenticated

2. Resend: Exists on VPS. New ISOLATED Podman secrets required for this app:
   - `bridge-ph-padang-demo-resend-key` — demo-specific key
   - `bridge-ph-padang-prod-resend-key` — production-specific key
   - Codex must create these via `podman secret create` when setting up the server
   - Owner must provide the Resend API key values separately

3. Caddy config: Caddyfile format (not JSON). Inspected. Key findings:
   - Config location on VPS: `/home/jk/caddy/conf/Caddyfile`
   - Follows PIMASCOR pattern: separate handler files imported inside `delegateops.business { }`
   - PIMASCOR frontend = static file serving (Vite SPA). Padang = Next.js (reverse proxy — different!)
   - Proxy network pattern: Caddy is NOT on the internal app network; uses dedicated proxy networks
   - See docs/DEPLOYMENT.md for exact Caddyfile snippets and caddy.container additions
   - See ADR-007 for full routing decision rationale
   - CSP: new `padang_nextjs_csp` snippet required (Next.js needs 'unsafe-inline' for hydration)
   - Phase 2: replace 'unsafe-inline' with nonce-based CSP via Next.js middleware

4. DCS = CEO of Padang (confirmed). The DCS role is not a generic finance employee.
   It is the company owner/CEO acting as the sole check-signing authority.
   Design implication: the DCS interface should be treated as an executive-level view;
   minimal steps, maximum clarity on what is being paid and why.

---

ARCHITECTURAL DECISIONS (all resolved):
- Go (latest stable, `golang:alpine`) + Chi v5 — idiomatic, minimal, long-lived ERP backend
- Next.js 16 App Router (active LTS, `node:lts-alpine`) + TypeScript + shadcn/ui + Tailwind CSS v4
- PostgreSQL 17 (`postgres:17-alpine`, major version pinned, patch auto-updates via podman)
- sqlc + pgx v5 — type-safe SQL, no ORM
- golang-migrate — DB migrations (up/down SQL files)
- Backblaze B2 (existing bucket `bridge-ph`) — file storage + production backups
- Resend → Azure (future) — provider-neutral email adapter
- Rootless Podman Quadlets — all containers; `AutoUpdate=registry`; no pinned version numbers
- All builds via `podman run --rm`; multi-stage Containerfiles; no host build toolchain
- Path-based routing: /padang (prod), /padang/demo (demo) — existing Caddy; PIMASCOR pattern
- Proxy network architecture: Caddy + frontend + API on proxy.network; API + DB on internal.network
- Email OTP (passwordless) — 6-digit code, 10-min TTL, single-use, rate-limited; no passwords stored
- RS256 JWT — access (15min) + refresh (7d, rotating, server-side hashed)
- GHCR `itsadventuretime` as OCI registry
- Git remote: https://github.com/ItsAdventureTime/bridge-padang.git
- VAT 12% + EWT 2% at launch — BIR-compliant billing documents
- Retention 10% per billing + release mechanism — CIAP standard
- Variation Orders (10% cumulative cap) — at launch
- RPO ≤ 24h (daily pg_dump to B2); RTO ≤ 4h — recommended defaults
- DCS = CEO of Padang — executive-level payment execution interface

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
- `git remote add origin https://github.com/ItsAdventureTime/bridge-padang.git` (via `gh`)
- File creation and documentation only

TESTS EXECUTED: None (Phase 0 is documentation only)
TEST RESULTS: N/A
KNOWN FAILURES: None
KNOWN RISKS:
- Next.js CSP: 'unsafe-inline' needed for Phase 1 hydration; Phase 2 hardening required
- Resend isolated keys: Codex must create via `podman secret create` (owner provides key values)
- caddy.container needs two Network= lines added before Caddy is updated; requires VPS SSH access
- DB user for demo: `padang_demo_user` must be created during DB init with correct password

---

UNRESOLVED QUESTIONS:
None. All questions from initial Phase 0 architecture review are resolved.

OPEN DEFECTS: None

---

NEXT REQUIRED ACTION:
ChatGPT Codex to begin Phase 1 — Database Schema & Migrations.

Phase 1 scope:
1. Set up repository structure per docs/ARCHITECTURE.md (backend/)
2. Initialize Go module: `go mod init github.com/ItsAdventureTime/padang-erp`
   - Use `gh` CLI for any GitHub operations (HTTPS auth, no SSH)
3. Add core Go dependencies:
   - `go-chi/chi/v5`
   - `jackc/pgx/v5`
   - `sqlc-dev/sqlc` (also install sqlc CLI)
   - `golang-migrate/migrate/v4`
   - `go-playground/validator/v10`
4. Set up golang-migrate with PostgreSQL dialect
5. Write migration files for ALL tables defined in docs/DATABASE.md:
   - users, refresh_tokens
   - projects, project_budget_items, project_variation_orders, project_progress_entries
   - fabrication_jobs
   - suppliers, purchase_requests, purchase_request_items, purchase_orders
   - fund_requests
   - inventory_items, inventory_transactions
   - progress_billings, progress_billing_items, collections
   - attachments (polymorphic)
   - audit_log (append-only; include DB rule/trigger to prevent UPDATE/DELETE)
   - All sequences for reference number generation
   - All indexes documented in DATABASE.md
6. Set up sqlc.yaml and write initial query files for: users CRUD, projects CRUD
7. Set up Podman-based local development: throwaway PostgreSQL 17 container for migration testing
8. Verify all migrations run up and down cleanly against a test database
9. Write the initial commit: `feat(db): initial schema migrations and sqlc setup`
10. Push to `origin/feat/phase-1-db-migrations` branch

NEXT AGENT: ChatGPT Codex (Implementation Engineer)

REQUIRED READING (for Codex):
1. AGENTS.md — project map and role assignments
2. docs/PROJECT_CONSTITUTION.md — engineering rules (especially macOS execution policy, secrets policy, Git rules)
3. docs/HANDOFF.md — this file
4. docs/ARCHITECTURE.md — directory structure, tech stack
5. docs/DATABASE.md — schema design and DDL (primary reference for migrations)
6. docs/SECURITY.md — secrets, RBAC
7. docs/DEPLOYMENT.md — naming conventions and network architecture

APPROVAL REQUIRED:
Phase 1 is pre-authorized. Codex may begin immediately.
Any material deviation from the documented architecture requires flagging to Antigravity (Architect) before proceeding.

---

CONTEXT FOR VPS WORK (Phases 5-6):
- VPS access: SSH as user `jk`
- Git operations: use `gh` CLI; HTTPS only; already authenticated
- No SSH keys or passkeys required for GitHub operations
- Caddy config path: `/home/jk/caddy/conf/Caddyfile`
- Quadlet path: `/home/jk/.config/containers/systemd/bridge-ph/`
- When updating caddy.container: add Network lines; reload `systemctl --user daemon-reload`; restart `caddy.service`
- Resend API keys: owner provides values; Codex creates secrets via `podman secret create bridge-ph-padang-{env}-resend-key -`
