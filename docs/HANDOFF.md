# HANDOFF.md — Padang ERP Lite

---

CURRENT AGENT: ChatGPT Codex (Implementation Engineer)
CURRENT PHASE: C1 — implementation and containerized validation
STATUS: `GO: CODEX C1` received. Foundation implementation, Luna review
remediation, documentation updates, deployment-update workflow, containerized
validation, frontend npm cache remediation, Caddy route insertion remediation,
offline font build remediation, and bounded route/UX remediation are complete.
The public release gate is currently failing with HTTP 404; the full ERP
workflow surface is not yet implemented.
BRANCH: main
BASE COMMIT: bbdd803
LATEST IMPLEMENTATION COMMIT: 8f482aa (`fix(frontend): make font builds offline-safe`)
REMOTE: https://github.com/ItsAdventureTime/bridge-padang.git
REMOTE PUSH STATUS: `main` is the GitHub default branch and contains the
consolidated implementation; updates were pushed through the authenticated
HTTPS GitHub CLI path
DEMO VPS SSH TARGET: `jk@216.75.75.136:22`
DEMO UPDATE COMMAND: `scripts/update-padang-demo.sh`
DEMO PUBLIC URL: `https://delegateops.business/padang/demo`
PRODUCTION PUBLIC URL: `https://delegateops.business/padang`

## C1 Review and Remediation Record

The Luna reviewer identified authentication race conditions, stale production
role claims, demo-role UI drift, incomplete OTP login, attachment validation
gaps, workflow-transition bypasses, variation-order boundary behavior,
transactional audit coverage, secret-input confirmation, OpenAPI drift, and
request-ID response metadata. The executor remediation and integration pass
address those C1 findings. Remaining hardening work is explicitly tracked in
`docs/SECURITY.md` and is not a deployment authorization.

## Deployment Update Remediation (2026-08-14)

The attached macOS CLI log showed SSH synchronization and backend validation
passing, followed by frontend `npm ci` failing with `ENOENT: mkdir '/src/.npm'`.
The source mount is intentionally read-only, so the remote frontend builder now
uses a disposable `/tmp` tmpfs and fresh writable npm `HOME`, cache, and user
config paths. A container-level `npm ci --ignore-scripts` probe against the
read-only source mount passes with this configuration. Recovery guidance is in
`docs/OPERATIONS.md`; the normal update command remains
`scripts/update-padang-demo.sh`.

The previous `docs/phase-0` and `feat/c1-foundation` branches remain as
historical references. Both are ancestors of `main` and contain no divergent
work requiring a separate merge or repair.

## Caddy Deployment Remediation (2026-08-14)

The next demo update completed backend and frontend validation but stopped when
the remote script could not find the literal `# DelegateOps static-site
fallback` comment in the existing Caddyfile. The updater now manages the
documented `padang-demo.handlers.Caddyfile` import inside the
`delegateops.business` site block, supports the older marker and generic
`handle { ... }` fallback, preserves an existing inline managed route, and
fails closed when no unambiguous site/fallback exists. It stages and validates
the assembled Caddyfile with disposable Caddy tooling before changing the
timestamped backups or reloading Caddy. Local insertion fixtures cover legacy,
generic, and unsafe layouts.

## Offline Font Build Remediation (2026-08-14)

The frontend no longer imports fonts through `next/font/google`, which caused
VPS `next build` failures when Google Fonts was unreachable. Outfit, Inter, and
JetBrains Mono now come from Fontsource variable packages installed by
`npm ci`; the existing CSS font-role variables remain unchanged. The focused
`frontend` check `npm run check:offline-fonts` verifies the layout import and
package/lockfile metadata. The VPS build still needs npm registry access (or a
configured npm cache) to install dependencies, but no Google Fonts access.

## End-to-End Review and Bounded Remediation (2026-08-14)

The Luna reviewer audited startup, workflows, API/UI alignment, navigation,
responsive/accessibility concerns, and visual consistency. The app is not
release-ready:

- `https://delegateops.business/padang/demo`, `/padang`, and both documented
  health URLs returned HTTP 404 from BunnyCDN;
- a direct `--resolve` request to `216.75.75.136` also returned HTTP 404 from
  Caddy, so the public route failure is not only a CDN symptom;
- the frontend currently provides a dashboard and generic read-only module
  registers; dedicated CRUD, approval, payment, QBO, and reporting workflows
  remain future implementation work.

This pass adds `scripts/check-padang-public-routes.sh` and
`scripts/start-padang-local.sh`, makes unknown module slugs return 404, fixes
basePath-aware active navigation and direct API-origin URL construction, and
marks unfinished controls as disabled/read-only. The public route matrix,
complete ERP workflows, and live browser accessibility verification remain
release blockers.

---

## Specification Overview & Architectural Decisions

The resolved intake decisions and their detailed explanations are in
`docs/PLANNING_CLARIFICATIONS.md`. They are normative for implementation
planning and supersede older contradictory wording in this document.

1. **Brand & UI/UX**: Light Corporate Enterprise UI (Primary launch theme). Clean white (`#FFFFFF`) and slate (`#F8FAFC`) surfaces, crisp data tables, rich gold (`#C8A84B`, `#D4A843`) brand accents derived from the official logo. Typography: Outfit (display), Inter (UI), JetBrains Mono (financial figures). Logo vector SVG to be generated at `frontend/public/assets/padang-logo.svg`.
2. **Tech Stack**:
   - Backend: latest supported Go release (`golang:alpine`) + Chi. sqlc + pgx for type-safe database queries. golang-migrate for SQL migrations.
   - Frontend: latest supported Next.js App Router release + TypeScript + Tailwind CSS + shadcn/ui + TanStack Query/Table, built with the official floating `node:lts-alpine` image.
   - RDBMS: latest supported PostgreSQL release via floating `postgres:alpine`.
   - File Storage: Backblaze B2 (`bridge-ph` bucket, prefix `padang/demo/` for demo, `padang/` for prod). Shared keys stored in separate Podman secrets per environment (`bridge-ph-padang-{env}-b2-key-id`, `bridge-ph-padang-{env}-b2-application-key`).
   - Email: Resend Go SDK with swappable adapter pattern (`EMAIL_PROVIDER=resend`) in production; demo uses the log adapter and does not send email.
   - Auth: Production uses passwordless Email OTP (6-digit, 10-min TTL, bcrypt hash in DB, rate-limited) + RS256 JWT (15-min access, 7-day rotating refresh cookie). Demo has no authentication and uses a guarded synthetic identity with validated header-based role switching (`X-Demo-Role`).
3. **Philippine Regulatory Compliance**:
   - VAT: 12% on gross billings.
   - EWT: 2% creditable withholding tax (configurable toggle per client, BIR Form 2307 reference tracking).
   - Retention: 10% standard deduction per progress billing; running total retained payable tracking.
   - Variation Orders: Cumulative cap at 10% of contract amount (8% warning alert, 10% hard stop alert).
4. **Container & Infrastructure Design**:
   - Rootless Podman Quadlets with floating channel tags and no auto-update
     policy; the timer stays disabled and updates remain operator-triggered.
   - Proxy-Network isolation pattern: Caddy + Frontend + API on `proxy.network`; API + DB on internal `network`. DB is non-routable from host or edge.
   - Ingress: Path-based routing via existing Caddy (`/padang` prod, `/padang/demo` demo). Frontend is built twice from one source revision because Next.js `basePath` is build-time.
   - Production target: Quadlets at `/home/jk/.config/containers/systemd/bridge-ph/padang/`, persistent state at `/home/jk/bridge-ph/padang/`, and release identity `padang-bridge-ph:prod`.

### Planning Clarification Decisions

- One source codebase, separate demo and production frontend artifacts.
- Canonical role identifiers use full names everywhere; abbreviations are not
  valid API/database values.
- The schema addendum covers clients/tax profiles, project and fabrication
  costing, estimates/deliveries/billings, PO lines, supplier payments, finance
  operations, retention, collections, and QBO export history.
- A dedicated backup utility image contains both PostgreSQL client tools and
  rclone configured for Backblaze B2's S3-compatible API; the previous
  PostgreSQL-only backup example was invalid.
- The API is the shared boundary for web and future Expo/React Native clients.
- The launch design is light-only, with self-hosted Fontsource fonts and light
  CSP-compatible tokens.
- Demo reset is operator/systemd-only and fails closed on environment/database
  identity checks.

---

## Detailed Implementation Tasks for ChatGPT Codex

Codex must implement the application sequentially following the ordered tasks below.

---

### TASK-001: Database Schema & Migrations
- **GOAL:** Initialize repository structure (`backend/`), set up Go module, write complete database migration files for the latest supported PostgreSQL release, set up `sqlc`, and verify migrations.
- **CONTEXT:** Schema design is specified in `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/`, `backend/migrations/`, `backend/sqlc.yaml`, `backend/internal/repository/`
- **DEPENDENCIES:** None
- **CONSTRAINTS:**
  - Use `golang-migrate` (v4 format: `{timestamp}_{desc}.up.sql` / `.down.sql`).
  - Primary keys: UUID v4 (`gen_random_uuid()`).
  - Soft deletes: `deleted_at TIMESTAMPTZ`.
  - Monetary values: `NUMERIC(18,4)`. Percentages: `NUMERIC(7,4)`.
  - Append-only `audit_log` table with DB-level or application-level rules preventing UPDATE/DELETE.
  - All indexes, sequences (`seq_pr_number`, `seq_po_number`, `seq_fr_number`), and polymorphic `attachments` table.
- **ACCEPTANCE CRITERIA:**
  - All tables from `docs/DATABASE.md` created with constraints, foreign keys, and indexes.
  - Up and down migrations execute without errors against the selected floating PostgreSQL image.
  - `sqlc generate` generates type-safe Go structs and query functions cleanly.
- **REQUIRED TESTS:** Ephemeral Podman test running `golang-migrate` up and down against a clean `postgres:alpine` container.
- **DEFINITION OF DONE:** Migration files committed, `sqlc` configured and generating Go code, up/down test verified cleanly.

TASK-001 also includes the complete operational data-model addendum in
`docs/DATABASE.md` and ADR-012. No product workflow may be implemented with
an undocumented placeholder table.

---

### TASK-002: Go Backend Core API, Auth & Middleware
- **GOAL:** Build backend entrypoint (`cmd/api/main.go`), Chi router setup, layered architecture, Email OTP authentication, RS256 JWT issuance/refresh, RBAC middleware, B2 storage adapter, and Resend email adapter.
- **CONTEXT:** Architecture detailed in `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/API.md`.
- **FILES/AREAS:** `backend/cmd/api/`, `backend/internal/handler/`, `backend/internal/service/`, `backend/internal/middleware/`, `backend/internal/storage/`, `backend/internal/email/`
- **DEPENDENCIES:** TASK-001
- **CONSTRAINTS:**
  - Strict layered architecture (Handler → Service → Repository → Domain).
  - Production auth: Email OTP with 6-digit bcrypt-hashed single-use codes (10-min TTL, rate-limited: 3 req/15min, 5 verify attempts max).
  - Demo mode has no authentication; use a synthetic identity and accept
    `X-Demo-Role` only after validating the canonical demo role enum.
  - JWT RS256 tokens (15-min access, 7-day rotating refresh cookie).
  - Podman secrets read from `/run/secrets/`.
  - OpenAPI 3.1 handler at `/api/v1/openapi.json`.
  - Demo mode has no authentication and must fail closed outside `APP_ENV=demo`.
- **ACCEPTANCE CRITERIA:**
  - `GET /api/v1/health` returns `{"status":"ok"}`.
  - Complete OTP request & verify flow works in production mode; demo mode
    uses only its guarded synthetic identity.
  - RBAC middleware enforces permissions matrix defined in `docs/SECURITY.md`.
  - File upload service generates presigned B2 URLs; email service logs or sends via Resend adapter.
- **REQUIRED TESTS:** Go unit tests for OTP generation/hashing, JWT issuance, RBAC middleware permissions; integration test for health endpoint.
- **DEFINITION OF DONE:** All core middleware, auth, storage, and email adapters implemented and unit tested.

---

### TASK-003: Next.js Frontend Shell & Design System (Light Corporate)
- **GOAL:** Initialize Next.js App Router in `frontend/`, configure the latest supported Tailwind CSS release, shadcn/ui, custom light corporate theme, font imports (Outfit, Inter, JetBrains Mono), logo SVG asset, collapsible sidebar, top bar with demo role switcher, and OpenAPI TypeScript generator.
- **CONTEXT:** Governed by `docs/DESIGN_SYSTEM.md` and `docs/UI_UX.md`.
- **FILES/AREAS:** `frontend/app/`, `frontend/components/`, `frontend/public/assets/`, `frontend/lib/`, `frontend/types/`
- **DEPENDENCIES:** TASK-002 (for OpenAPI spec)
- **CONSTRAINTS:**
  - Light corporate enterprise aesthetic (crisp white `#FFFFFF`, slate `#F8FAFC`, gold `#C8A84B` / `#D4A843` brand accents).
  - Generate clean SVG logo from root photo assets at `frontend/public/assets/padang-logo.svg`.
  - Setup `openapi-typescript` script to generate frontend types from backend spec.
  - Support `basePath` configuration (`/padang` prod, `/padang/demo` demo).
  - Build two frontend artifacts from one source revision: `demo-latest` for
    `/padang/demo` and `latest` for `/padang`; `basePath` is build-time.
  - Role switcher in top bar for demo mode.
- **ACCEPTANCE CRITERIA:**
  - Layout renders crisp sidebar, header, breadcrumbs, role selector, and content area.
  - Fully responsive (desktop sidebar, tablet collapse, mobile drawer).
  - PHP currency formatter (`formatPHP`) formatted in JetBrains Mono.
- **REQUIRED TESTS:** Frontend build (`npm run build`), type check (`npm run typecheck`), lint (`npm run lint`).
- **DEFINITION OF DONE:** Next.js application shell compiles, renders Light Corporate theme, and generates types cleanly.

---

### TASK-004: Projects & Fabrication Modules
- **GOAL:** Implement complete backend APIs and frontend UI for Projects (Master, BOQ Budget, Costing, Progress, VOs, Documents, Profitability) and Fabrication (Estimates, Job Orders, Production, Delivery, Billing, Profitability).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/project/`, `backend/internal/domain/fabrication/`, `frontend/app/(dashboard)/projects/`, `frontend/app/(dashboard)/fabrication/`
- **DEPENDENCIES:** TASK-002, TASK-003
- **CONSTRAINTS:**
  - Enforce Variation Order 10% cumulative cap logic (warning alert at 8%, error alert at 10%).
  - Calculate BOQ weighted completion percentage.
  - File attachments uploaded to B2 under polymorphic `attachments` table.
  - Standalone or Project-linked Fabrication job orders.
- **ACCEPTANCE CRITERIA:**
  - Full CRUD operations for Projects, BOQ items, VOs, and Progress entries.
  - Full CRUD for Fabrication Estimates, Job Orders, and Delivery receipts.
  - Profitability reports calculate accurate gross margins.
- **REQUIRED TESTS:** Go unit tests for VO cap calculations, BOQ completion weighting, and fab margin logic.
- **DEFINITION OF DONE:** Projects and Fabrication modules operational end-to-end on both API and UI layers.

---

### TASK-005: Procurement & Inventory Modules
- **GOAL:** Implement backend APIs and frontend UI for Procurement (PRs, POs, Supplier SOA, Fund Requests with GM/DCS queues) and Inventory (Item Master, Stock In, Stock Out, Material Issues, Direct-to-Project).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/procurement/`, `backend/internal/domain/inventory/`, `frontend/app/(dashboard)/procurement/`, `frontend/app/(dashboard)/inventory/`
- **DEPENDENCIES:** TASK-004
- **CONSTRAINTS:**
  - Auto-generate reference numbers (`PR-YYYY-####`, `PO-YYYY-####`, `FR-YYYY-####`) via DB sequences.
  - Enforce financial workflow: Draft → Submitted → GM Approval → DCS for Payment → Completed.
  - Recalculate inventory weighted average cost on Stock In.
  - Direct-to-Project materials bypass warehouse inventory count while capturing project costing.
- **ACCEPTANCE CRITERIA:**
  - Complete PR → PO → Fund Request → DCS Payment execution flow.
  - GM pending approvals queue and DCS payment queue correctly display pending items.
  - Inventory stock movements update item balances and weighted average cost accurately.
- **REQUIRED TESTS:** Go unit tests for weighted average cost calculation and disbursement state machine transitions.
- **DEFINITION OF DONE:** Procurement and Inventory pipelines fully integrated and tested.

---

### TASK-006: Billing & Collections, Finance Operations
- **GOAL:** Implement Progress Billing (BOQ-linked, 10% retention, 12% VAT, 2% EWT), Collection Monitoring (partial payments, OR/AR numbers), AR Aging Report, and Finance Ops (Reimbursements, Liquidations, Supplier Payments).
- **CONTEXT:** Specifications in `docs/PRODUCT.md`, `docs/API.md`, `docs/DATABASE.md`.
- **FILES/AREAS:** `backend/internal/domain/billing/`, `backend/internal/domain/finance/`, `frontend/app/(dashboard)/billing/`, `frontend/app/(dashboard)/finance/`
- **DEPENDENCIES:** TASK-005
- **CONSTRAINTS:**
  - Progress Billing calculations:
    - Gross = $\sum (\text{current \%} \times \text{contract rate})$
    - Retention = $10\% \times \text{gross}$
    - VAT = $12\% \times \text{gross}$
    - EWT = $2\% \times \text{gross}$ (if client EWT enabled)
    - Net = Gross - Retention + VAT - EWT
  - Billing workflow: Draft → GM Approval → Issued to Client → Collection → Completed.
  - Aging buckets: Current, 30d, 60d, 90d, 90d+.
  - Print layout for billings (Padang letterhead, clean white print styling).
- **ACCEPTANCE CRITERIA:**
  - Progress billing correctly computes retention, VAT, and EWT.
  - Collections update billing status and maintain running AR balance.
  - Printable billing layout renders cleanly in browser print preview.
- **REQUIRED TESTS:** Go unit tests for billing mathematical formulas (retention, VAT, EWT, net due, cumulative totals).
- **DEFINITION OF DONE:** Billing & Collections and Finance Operations modules fully functional with print and aging capabilities.

---

### TASK-007: Reports & QBO Export Engine
- **GOAL:** Implement filterable reporting endpoints/pages and QBO export engine generating structured Excel (.xlsx) and CSV files.
- **CONTEXT:** Specifications in `docs/PRODUCT.md` (Reports & QBO sections) and `docs/API.md`.
- **FILES/AREAS:** `backend/internal/domain/report/`, `backend/internal/domain/qbo/`, `frontend/app/(dashboard)/reports/`
- **DEPENDENCIES:** TASK-006
- **CONSTRAINTS:**
  - Filter reports by date range, project, client, supplier.
  - QBO Export types: Customers, Vendors, Bills, Expenses, Invoices, Collections, Payments.
  - Include QBO mapping headers, sync status flag, and export timestamp.
- **ACCEPTANCE CRITERIA:**
  - All 8 standard reports render data tables and export to Excel/CSV.
  - QBO export files generate valid `.xlsx` and `.csv` files matching QBO import schema.
- **REQUIRED TESTS:** Go unit tests for QBO export file generators.
- **DEFINITION OF DONE:** All reports and QBO export channels operational and verified.

---

### TASK-008: Synthetic Demo Seed Data & 30-Minute Automatic Reset
- **GOAL:** Create realistic synthetic demo seed SQL script (`seed/demo_seed.sql`) and implement one-shot reset container/binary with systemd 30-minute timer definition.
- **CONTEXT:** Detailed in `docs/DEPLOYMENT.md`, `docs/TESTING.md`, `docs/UI_UX.md`.
- **FILES/AREAS:** `seed/demo_seed.sql`, `backend/cmd/seed/`, `quadlets/demo/bridge-ph-padang-demo-reset.container`, `quadlets/demo/bridge-ph-padang-demo-reset.timer`
- **DEPENDENCIES:** TASK-007
- **CONSTRAINTS:**
  - Seed data MUST be realistic and rich: 3–5 projects in varied statuses, 3–5 fab jobs, suppliers, inventory, progress billings with partial collections, pending GM and DCS approvals.
  - Seed process MUST be idempotent (TRUNCATE tables with RESTART IDENTITY → INSERT seed records).
  - Reset container MUST connect strictly to `padang_demo` database and cannot physically/logically reach `padang_prod`.
  - Reset must fail closed on missing or contradictory `APP_ENV`, `RUN_MODE`,
    database, or resolved-target guards.
- **ACCEPTANCE CRITERIA:**
  - Running seed script populates demo DB with complete operational state across all roles.
  - Running reset container wipes modified demo data and restores clean seed state.
- **REQUIRED TESTS:** Integration test verifying demo reset restores exact initial record counts.
- **DEFINITION OF DONE:** Demo seed script and automatic 30-minute reset Quadlet container complete and verified.

---

### TASK-009: Containerization, Quadlets & Production Readiness
- **GOAL:** Write multi-stage Containerfiles for Go API and Next.js frontend, complete all Quadlet definitions (demo + prod), Caddy configuration snippets, secret setup script, backup script, and deployment documentation verification.
- **CONTEXT:** Specifications in `docs/DEPLOYMENT.md`, `docs/BACKUP_RESTORE.md`, `docs/OPERATIONS.md`.
- **FILES/AREAS:** `backend/Containerfile`, `frontend/Containerfile`, `quadlets/demo/`, `quadlets/prod/`, `scripts/`, `docs/caddy-reference/`
- **DEPENDENCIES:** TASK-008
- **CONSTRAINTS:**
  - All container builds executed via `podman run --rm`; multi-stage Containerfiles; no host build tools.
  - Quadlet image tags remain floating, but no `AutoUpdate` policy is declared;
    the deployment wrapper is the controlled update boundary.
  - Caddy CSP snippet includes `padang_nextjs_csp`.
  - Secrets setup script (`scripts/secrets-setup.sh`) manages all required Podman secrets.
  - Dedicated backup utility image runs the database and attachment backup;
    `pg_dump -Fc` streams directly to B2 with manifest/checksum verification.
  - Backup uses the dedicated utility image specified by ADR-013, including
    `pg_dump`, rclone, and attachment manifests/checksums.
- **ACCEPTANCE CRITERIA:**
  - Backend and frontend containers build cleanly via Podman.
  - All Quadlet systemd files pass validation.
  - Full application stack (DB, API, Frontend) runs cleanly in containerized environment.
- **REQUIRED TESTS:** Container build test and end-to-end container health check.
- **DEFINITION OF DONE:** Complete containerized deployment package ready for VPS deployment.

---

## Instructions for ChatGPT Codex (Implementer)

1. Read `AGENTS.md`, `docs/PROJECT_CONSTITUTION.md`, and `docs/HANDOFF.md` before starting.
2. Implement tasks sequentially from **TASK-001** through **TASK-009**.
3. Do not modify architectural boundaries, database DDL principles, or security models without architect approval.
4. Execute runtime tests using `podman run --rm` per the macOS execution policy.
5. Create feature branches (`feat/task-001-db-migrations`, etc.) for implementation commits.
6. Record exact verification results for each task.

---

## Authorization & Handoff State

- **Phase A1 Status:** COMPLETE, with planning clarification addendum applied.
- **Current instruction:** **GO: CODEX C1** is active. Implement sequentially,
  validate runtime/build/test work only in disposable Podman containers, and do
  not deploy to the VPS during C1. Update this handoff with exact results before
  committing and pushing the working branch; the reviewed C1 history is now
  consolidated on `main`.

## C1 Implementation and Validation Log

- Branch: `main`; consolidated source history: `feat/c1-foundation` and
  `docs/phase-0`; base: `bbdd803`.
- Database: foundation migration up/down and `sqlc generate` validated in
  disposable containers; seed/reset restored the exact `10|3|2` baseline for
  users/projects/progress billings after create/update/delete changes.
- Backend: `go test ./...`, `go vet ./...`, and the API Containerfile build pass.
  Demo health, guarded dashboard access, security headers, and disabled auth
  smoke checks pass in a disposable container.
- Frontend: npm lockfile install, typecheck, lint, demo build
  (`/padang/demo`), production build (`/padang`), and demo standalone runtime
  smoke check pass in disposable Node containers.
- Operations: backup utility image build and production fail-closed guard pass;
  reset/backup/secrets shell syntax passes; Quadlet dry-run generation passes
  on the Podman Linux machine. No VPS deployment performed.
- Remaining release work: hand the implementation to Antigravity for
  independent A2 review. Production backup upload/restore and
  Caddy changes remain C2/C4 deployment activities and were not performed.

## Automated Padang Demo Deployment Workflow

- macOS performs only the synchronized-source upload and remote handoff;
  compilation, tests, package installation, and runtime startup occur on the
  VPS in disposable `podman run --rm` containers.
- The default deployment endpoint is `jk@216.75.75.136:22`; the public demo
  route remains `https://delegateops.business/padang/demo`.
- Routine updates use `scripts/update-padang-demo.sh` and preserve demo data;
  `--seed-demo` is reserved for an intentional synthetic-data reset.
- Application Quadlets omit `AutoUpdate=registry`; the remote updater refuses
  apply while `podman-auto-update.timer` is active or enabled.
- Padang demo Quadlets install under
  `/home/jk/.config/containers/systemd/bridge-ph/padang-demo/`; persistent
  state installs under `/home/jk/bridge-ph/padang-demo/`.
- The VPS generates and persists the database username in
  `config/db-user`, generates the database password directly into a Podman
  secret, and prompts interactively only for the two Backblaze B2 values.
- Caddy uses the official `/padang/demo` route with
  `/home/jk/caddy/conf/Caddyfile` and
  `/home/jk/.config/containers/systemd/caddy/caddy.container`; the staged
  Caddyfile is formatted and validated in disposable Caddy containers before
  replacement and graceful reload.
- Current local validation: shell syntax, ShellCheck, Caddy format/validate,
  and demo/production Quadlet generator checks pass. No VPS deployment was
  performed.
